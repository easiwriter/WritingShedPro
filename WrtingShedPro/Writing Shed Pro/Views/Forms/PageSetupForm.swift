//
//  PageSetupForm.swift
//  Writing Shed Pro
//
//  Per-project page setup configuration form
//  Page setup is stored in SwiftData and specific to each project
//

import SwiftUI
import SwiftData

struct PageSetupForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    
    @State private var paperName: String
    @State private var orientation: Int16
    @State private var headers: Bool
    @State private var footers: Bool
    @State private var facingPages: Bool
    @State private var leftMargin: Double
    @State private var rightMargin: Double
    @State private var topMargin: Double
    @State private var bottomMargin: Double
    @State private var headerDepth: Double
    @State private var footerDepth: Double
    @State private var scaleFactor: Double
    @State private var pageBreakBetweenFiles: Bool
    @State private var units: Units
    
    // Track original values to detect changes
    @State private var originalPaperName: String = ""
    @State private var originalOrientation: Int16 = 0
    @State private var originalHeaders: Bool = false
    @State private var originalFooters: Bool = false
    @State private var originalFacingPages: Bool = false
    @State private var originalTopMargin: Double = 0
    @State private var originalLeftMargin: Double = 0
    @State private var originalBottomMargin: Double = 0
    @State private var originalRightMargin: Double = 0
    @State private var originalHeaderDepth: Double = 0
    @State private var originalFooterDepth: Double = 0
    @State private var originalScaleFactor: Double = 0
    @State private var originalPageBreakBetweenFiles: Bool = false
    
    init(project: Project) {
        self.project = project
        
        // Initialize with empty values - will load in onAppear
        _paperName = State(initialValue: "")
        _orientation = State(initialValue: Orientation.portrait.rawValue)
        _headers = State(initialValue: false)
        _footers = State(initialValue: false)
        _facingPages = State(initialValue: false)
        _leftMargin = State(initialValue: 0)
        _rightMargin = State(initialValue: 0)
        _topMargin = State(initialValue: 0)
        _bottomMargin = State(initialValue: 0)
        _headerDepth = State(initialValue: 0)
        _footerDepth = State(initialValue: 0)
        _scaleFactor = State(initialValue: 0)
        _pageBreakBetweenFiles = State(initialValue: false)
        _units = State(initialValue: .inches)
    }
    
    private func loadValues() {
        // Ensure project has a page setup
        if project.pageSetup == nil {
            project.pageSetup = PageSetup.createWithDefaults()
            try? modelContext.save()
        }
        
        guard let pageSetup = project.pageSetup else { return }
        
        // Load current values from project's page setup
        #if DEBUG
        print("[PageSetupForm] Loading values for project '\(project.name ?? "Untitled")'...")
        #endif
        paperName = pageSetup.paperName ?? PaperSizes.defaultForRegion.rawValue
        orientation = pageSetup.orientation
        headers = pageSetup.headers == 1
        footers = pageSetup.footers == 1
        facingPages = pageSetup.facingPages == 1
        leftMargin = pageSetup.marginLeft
        rightMargin = pageSetup.marginRight
        topMargin = pageSetup.marginTop
        bottomMargin = pageSetup.marginBottom
        headerDepth = pageSetup.headerDepth
        footerDepth = pageSetup.footerDepth
        scaleFactor = pageSetup.scaleFactor
        pageBreakBetweenFiles = PageSetupPreferences.shared.pageBreakBetweenFiles // Still global
        
        #if DEBUG
        print("[PageSetupForm] Loaded paperName: '\(paperName)'")
        #endif
        #if DEBUG
        print("[PageSetupForm] Loaded orientation: \(orientation)")
        #endif
        
        // Remember original values to detect changes
        originalPaperName = paperName
        originalOrientation = orientation
        originalHeaders = headers
        originalFooters = footers
        originalFacingPages = facingPages
        originalTopMargin = topMargin
        originalLeftMargin = leftMargin
        originalBottomMargin = bottomMargin
        originalRightMargin = rightMargin
        originalHeaderDepth = headerDepth
        originalFooterDepth = footerDepth
        originalScaleFactor = scaleFactor
        originalPageBreakBetweenFiles = pageBreakBetweenFiles
        
        #if DEBUG
        print("[PageSetupForm] Captured original paperName: '\(originalPaperName)'")
        #endif
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(NSLocalizedString("pageSetup.measurementUnits", comment: "Measurement units section")).font(.headline)) {
                    Picker(NSLocalizedString("pageSetup.measurementUnits", comment: "Measurement units picker"), selection: $units) {
                        Text(NSLocalizedString("units.points", comment: "Points")).tag(Units.points)
                        Text(NSLocalizedString("units.millimetres", comment: "Millimetres")).tag(Units.millimetres)
                        Text(NSLocalizedString("units.inches", comment: "Inches")).tag(Units.inches)
                    }
                }
                
                Section(header: Text(NSLocalizedString("pageSetup.orientation", comment: "Orientation section")).font(.headline)) {
                    Picker(NSLocalizedString("pageSetup.orientationPicker", comment: "Portrait/Landscape"), selection: $orientation) {
                        Text(NSLocalizedString("orientation.portrait", comment: "Portrait")).tag(Orientation.portrait.rawValue)
                        Text(NSLocalizedString("orientation.landscape", comment: "Landscape")).tag(Orientation.landscape.rawValue)
                    }
                }
                
                Section(header: Text(NSLocalizedString("pageSetup.paperSize", comment: "Paper size section")).font(.headline)) {
                    Picker(NSLocalizedString("pageSetup.paperSizePicker", comment: "Paper size"), selection: $paperName) {
                        Text(NSLocalizedString("paperSize.letter", comment: "Letter")).tag(PaperSizes.Letter.rawValue)
                        Text(NSLocalizedString("paperSize.legal", comment: "Legal")).tag(PaperSizes.Legal.rawValue)
                        Text(NSLocalizedString("paperSize.a4", comment: "A4")).tag(PaperSizes.A4.rawValue)
                        Text(NSLocalizedString("paperSize.a5", comment: "A5")).tag(PaperSizes.A5.rawValue)
                        Text(NSLocalizedString("paperSize.custom", comment: "Custom")).tag(PaperSizes.Custom.rawValue)
                    }
                    
                    if paperName == PaperSizes.Custom.rawValue {
                        NavigationLink {
                            Text(NSLocalizedString("pageSetup.customSize", comment: "Custom size view"))
                        } label: {
                            Text(NSLocalizedString("pageSetup.customSize", comment: "Custom size"))
                        }
                    }
                }
                
                Section(header: Text(NSLocalizedString("pageSetup.margins", comment: "Page margins section")).font(.headline)) {
                    HStack {
                        Text(NSLocalizedString("pageSetup.marginTop", comment: "Top margin"))
                            .frame(minWidth: 80, alignment: .leading)
                        TextField(NSLocalizedString("pageSetup.marginTop", comment: "Top"), value: $topMargin, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("pageSetup.marginLeft", comment: "Left margin"))
                            .frame(minWidth: 80, alignment: .leading)
                        TextField(NSLocalizedString("pageSetup.marginLeft", comment: "Left"), value: $leftMargin, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("pageSetup.marginBottom", comment: "Bottom margin"))
                            .frame(minWidth: 80, alignment: .leading)
                        TextField(NSLocalizedString("pageSetup.marginBottom", comment: "Bottom"), value: $bottomMargin, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("pageSetup.marginRight", comment: "Right margin"))
                            .frame(minWidth: 80, alignment: .leading)
                        TextField(NSLocalizedString("pageSetup.marginRight", comment: "Right"), value: $rightMargin, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section {
                    Toggle(NSLocalizedString("pageSetup.headers", comment: "Headers toggle"), isOn: $headers)
                    
                    if headers {
                        HStack {
                            Text(NSLocalizedString("pageSetup.depth", comment: "Depth"))
                                .frame(minWidth: 80, alignment: .leading)
                            TextField(NSLocalizedString("pageSetup.depth", comment: "Depth"), value: $headerDepth, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                Section {
                    Toggle(NSLocalizedString("pageSetup.footers", comment: "Footers toggle"), isOn: $footers)
                    
                    if footers {
                        HStack {
                            Text(NSLocalizedString("pageSetup.depth", comment: "Depth"))
                                .frame(minWidth: 80, alignment: .leading)
                            TextField(NSLocalizedString("pageSetup.depth", comment: "Depth"), value: $footerDepth, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                Section {
                    Toggle(NSLocalizedString("pageSetup.facingPages", comment: "Facing pages toggle"), isOn: $facingPages)
                }
                
                Section(header: Text("Multi-File Printing")) {
                    Toggle("Page break between files", isOn: $pageBreakBetweenFiles)
                        .accessibilityLabel("Add page breaks between files when printing collections or submissions")
                }
            }
            .navigationTitle(NSLocalizedString("pageSetup.title", comment: "Page Setup"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // ALWAYS reload values on appear to get latest from iCloud/prefs
                #if DEBUG
                print("[PageSetupForm] View appeared, loading values...")
                #endif
                loadValues()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pageSetupDidChange)) { _ in
                // Reload values when iCloud sync updates from another device
                #if DEBUG
                print("[PageSetupForm] Detected iCloud sync update, reloading values")
                #endif
                loadValues()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        savePageSetup()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePageSetup() {
        // Save values to project's PageSetup model
        guard let pageSetup = project.pageSetup else { return }
        
        #if DEBUG
        print("[PageSetupForm] ==================== SAVE CALLED ====================")
        #endif
        #if DEBUG
        print("[PageSetupForm] Saving for project: '\(project.name ?? "Untitled")'")
        #endif
        #if DEBUG
        print("[PageSetupForm] Current paperName: '\(paperName)'")
        #endif
        #if DEBUG
        print("[PageSetupForm] Original paperName: '\(originalPaperName)'")
        #endif
        
        if paperName != originalPaperName {
            #if DEBUG
            print("[PageSetupForm] ✅ Paper name changed: '\(originalPaperName)' → '\(paperName)'")
            #endif
            pageSetup.paperName = paperName
        }
        
        if orientation != originalOrientation {
            #if DEBUG
            print("[PageSetupForm] Orientation changed")
            #endif
            pageSetup.orientation = orientation
        }
        
        if headers != originalHeaders {
            #if DEBUG
            print("[PageSetupForm] Headers changed")
            #endif
            pageSetup.headers = headers ? 1 : 0
        }
        
        if footers != originalFooters {
            #if DEBUG
            print("[PageSetupForm] Footers changed")
            #endif
            pageSetup.footers = footers ? 1 : 0
        }
        
        if facingPages != originalFacingPages {
            #if DEBUG
            print("[PageSetupForm] Facing pages changed")
            #endif
            pageSetup.facingPages = facingPages ? 1 : 0
        }
        
        if abs(topMargin - originalTopMargin) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Top margin changed")
            #endif
            pageSetup.marginTop = topMargin
        }
        
        if abs(leftMargin - originalLeftMargin) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Left margin changed")
            #endif
            pageSetup.marginLeft = leftMargin
        }
        
        if abs(bottomMargin - originalBottomMargin) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Bottom margin changed")
            #endif
            pageSetup.marginBottom = bottomMargin
        }
        
        if abs(rightMargin - originalRightMargin) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Right margin changed")
            #endif
            pageSetup.marginRight = rightMargin
        }
        
        if abs(headerDepth - originalHeaderDepth) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Header depth changed")
            #endif
            pageSetup.headerDepth = headerDepth
        }
        
        if abs(footerDepth - originalFooterDepth) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Footer depth changed")
            #endif
            pageSetup.footerDepth = footerDepth
        }
        
        if abs(units.scaleFactor - originalScaleFactor) > 0.001 {
            #if DEBUG
            print("[PageSetupForm] Scale factor changed")
            #endif
            pageSetup.scaleFactor = units.scaleFactor
        }
        
        if pageBreakBetweenFiles != originalPageBreakBetweenFiles {
            #if DEBUG
            print("[PageSetupForm] Page break between files changed (global setting)")
            #endif
            PageSetupPreferences.shared.setPageBreakBetweenFiles(pageBreakBetweenFiles)
        }
        
        #if DEBUG
        print("[PageSetupForm] Saving to SwiftData...")
        #endif
        try? modelContext.save()
        #if DEBUG
        print("[PageSetupForm] Save complete")
        #endif
        
        // Note: Page setup changes will take effect on next document view refresh
        // Consider adding a notification to refresh open paginated views if needed
    }
}
