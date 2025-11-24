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
    @State private var units: Units
    
    init() {
        // Initialize from global page setup preferences
        _paperName = State(initialValue: PageSetupPreferences.shared.paperName)
        _orientation = State(initialValue: PageSetupPreferences.shared.orientation.rawValue)
        _headers = State(initialValue: PageSetupPreferences.shared.headers)
        _footers = State(initialValue: PageSetupPreferences.shared.footers)
        _facingPages = State(initialValue: PageSetupPreferences.shared.facingPages)
        _leftMargin = State(initialValue: PageSetupPreferences.shared.marginLeft)
        _rightMargin = State(initialValue: PageSetupPreferences.shared.marginRight)
        _topMargin = State(initialValue: PageSetupPreferences.shared.marginTop)
        _bottomMargin = State(initialValue: PageSetupPreferences.shared.marginBottom)
        _headerDepth = State(initialValue: PageSetupPreferences.shared.headerDepth)
        _footerDepth = State(initialValue: PageSetupPreferences.shared.footerDepth)
        _scaleFactor = State(initialValue: PageSetupPreferences.shared.scaleFactor)
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
        // Save to global page setup preferences (UserDefaults)
        prefs.setPaperName(paperName)
        prefs.setOrientation(Orientation(rawValue: orientation) ?? .portrait)
        prefs.setHeaders(headers)
        prefs.setFooters(footers)
        prefs.setFacingPages(facingPages)
        prefs.setMarginTop(topMargin)
        prefs.setMarginLeft(leftMargin)
        prefs.setMarginBottom(bottomMargin)
        prefs.setMarginRight(rightMargin)
        prefs.setHeaderDepth(headerDepth)
        prefs.setFooterDepth(footerDepth)
        prefs.setScaleFactor(units.scaleFactor)
        
        // Note: Page setup changes will take effect on next document view refresh
        // Consider adding a notification to refresh open paginated views if needed
    }
}
