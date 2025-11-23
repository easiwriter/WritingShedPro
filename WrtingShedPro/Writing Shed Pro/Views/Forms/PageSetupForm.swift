//
//  PageSetupForm.swift
//  Writing Shed Pro
//
//  Page setup configuration form
//

import SwiftUI
import SwiftData

struct PageSetupForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var project: Project
    
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
    @State private var units: Units
    
    init(project: Project) {
        self.project = project
        
        // Initialize from existing page setup or use defaults
        let pageSetup = project.pageSetup ?? PageSetup()
        
        _paperName = State(initialValue: pageSetup.paperName ?? PaperSizes.defaultForRegion.rawValue)
        _orientation = State(initialValue: pageSetup.orientation)
        _headers = State(initialValue: pageSetup.headers == 1)
        _footers = State(initialValue: pageSetup.footers == 1)
        _facingPages = State(initialValue: pageSetup.facingPages == 1)
        _leftMargin = State(initialValue: pageSetup.marginLeft)
        _rightMargin = State(initialValue: pageSetup.marginRight)
        _topMargin = State(initialValue: pageSetup.marginTop)
        _bottomMargin = State(initialValue: pageSetup.marginBottom)
        _headerDepth = State(initialValue: pageSetup.headerDepth)
        _footerDepth = State(initialValue: pageSetup.footerDepth)
        _scaleFactor = State(initialValue: pageSetup.scaleFactor)
        _units = State(initialValue: .inches)
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
            }
            .navigationTitle(NSLocalizedString("pageSetup.title", comment: "Page Setup"))
            .navigationBarTitleDisplayMode(.inline)
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
        // Get or create page setup
        let pageSetup = project.pageSetup ?? {
            let newPageSetup = PageSetup()
            project.pageSetup = newPageSetup
            return newPageSetup
        }()
        
        // Update properties
        pageSetup.paperName = paperName
        pageSetup.orientation = orientation
        pageSetup.headers = headers ? 1 : 0
        pageSetup.footers = footers ? 1 : 0
        pageSetup.facingPages = facingPages ? 1 : 0
        pageSetup.marginTop = topMargin
        pageSetup.marginLeft = leftMargin
        pageSetup.marginBottom = bottomMargin
        pageSetup.marginRight = rightMargin
        pageSetup.headerDepth = headerDepth
        pageSetup.footerDepth = footerDepth
        pageSetup.scaleFactor = units.scaleFactor
        
        // Update scale factor for all printer papers
        pageSetup.printerPapers?.forEach { paper in
            paper.scalefactor = units.scaleFactor
        }
        
        // Update project modified date
        project.modifiedDate = Date()
        
        // Save context
        try? modelContext.save()
    }
}
