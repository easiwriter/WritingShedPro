//
//  PageSetupForm.swift
//  Writing Shed Pro
//
//  Global page setup configuration form
//  Page setup is stored in UserDefaults and applies to all projects
//

import SwiftUI

struct PageSetupForm: View {
    @Environment(\.dismiss) private var dismiss
    
    private let prefs = PageSetupPreferences.shared
    
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
    
    init() {
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
        // Load current values from preferences
        print("[PageSetupForm] Loading values from preferences...")
        paperName = prefs.paperName
        orientation = prefs.orientation.rawValue
        headers = prefs.headers
        footers = prefs.footers
        facingPages = prefs.facingPages
        leftMargin = prefs.marginLeft
        rightMargin = prefs.marginRight
        topMargin = prefs.marginTop
        bottomMargin = prefs.marginBottom
        headerDepth = prefs.headerDepth
        footerDepth = prefs.footerDepth
        scaleFactor = prefs.scaleFactor
        pageBreakBetweenFiles = prefs.pageBreakBetweenFiles
        
        print("[PageSetupForm] Loaded paperName: '\(paperName)'")
        print("[PageSetupForm] Loaded orientation: \(orientation)")
        
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
        
        print("[PageSetupForm] Captured original paperName: '\(originalPaperName)'")
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
                print("[PageSetupForm] View appeared, loading values...")
                loadValues()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pageSetupDidChange)) { _ in
                // Reload values when iCloud sync updates from another device
                print("[PageSetupForm] Detected iCloud sync update, reloading values")
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
        // CRITICAL: Only save values that have actually changed from the original values
        // Compare against the values captured when the form opened, not current prefs
        // This prevents overwriting iCloud changes from other devices
        
        print("[PageSetupForm] ==================== SAVE CALLED ====================")
        print("[PageSetupForm] Current paperName: '\(paperName)'")
        print("[PageSetupForm] Original paperName: '\(originalPaperName)'")
        print("[PageSetupForm] Are they equal? \(paperName == originalPaperName)")
        
        if paperName != originalPaperName {
            print("[PageSetupForm] ✅ Paper name changed: '\(originalPaperName)' → '\(paperName)'")
            prefs.setPaperName(paperName)
            print("[PageSetupForm] ✅ Saved to prefs, verifying...")
            print("[PageSetupForm] ✅ Prefs now has: '\(prefs.paperName)'")
        } else {
            print("[PageSetupForm] ❌ Paper name NOT changed, skipping save")
        }
        
        if orientation != originalOrientation {
            print("[PageSetupForm] Orientation changed")
            prefs.setOrientation(Orientation(rawValue: orientation) ?? .portrait)
        }
        
        if headers != originalHeaders {
            print("[PageSetupForm] Headers changed")
            prefs.setHeaders(headers)
        }
        
        if footers != originalFooters {
            print("[PageSetupForm] Footers changed")
            prefs.setFooters(footers)
        }
        
        if facingPages != originalFacingPages {
            print("[PageSetupForm] Facing pages changed")
            prefs.setFacingPages(facingPages)
        }
        
        if abs(topMargin - originalTopMargin) > 0.001 {
            print("[PageSetupForm] Top margin changed")
            prefs.setMarginTop(topMargin)
        }
        
        if abs(leftMargin - originalLeftMargin) > 0.001 {
            print("[PageSetupForm] Left margin changed")
            prefs.setMarginLeft(leftMargin)
        }
        
        if abs(bottomMargin - originalBottomMargin) > 0.001 {
            print("[PageSetupForm] Bottom margin changed")
            prefs.setMarginBottom(bottomMargin)
        }
        
        if abs(rightMargin - originalRightMargin) > 0.001 {
            print("[PageSetupForm] Right margin changed")
            prefs.setMarginRight(rightMargin)
        }
        
        if abs(headerDepth - originalHeaderDepth) > 0.001 {
            print("[PageSetupForm] Header depth changed")
            prefs.setHeaderDepth(headerDepth)
        }
        
        if abs(footerDepth - originalFooterDepth) > 0.001 {
            print("[PageSetupForm] Footer depth changed")
            prefs.setFooterDepth(footerDepth)
        }
        
        if abs(units.scaleFactor - originalScaleFactor) > 0.001 {
            print("[PageSetupForm] Scale factor changed")
            prefs.setScaleFactor(units.scaleFactor)
        }
        
        if pageBreakBetweenFiles != originalPageBreakBetweenFiles {
            print("[PageSetupForm] Page break between files changed")
            prefs.setPageBreakBetweenFiles(pageBreakBetweenFiles)
        }
        
        print("[PageSetupForm] Save complete")
        
        // Note: Page setup changes will take effect on next document view refresh
        // Consider adding a notification to refresh open paginated views if needed
    }
}
