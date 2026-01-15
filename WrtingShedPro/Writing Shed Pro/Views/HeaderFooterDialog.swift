
import SwiftUI

enum HeaderFooterField: String, CaseIterable, Identifiable {
    case left
    case center
    case right
    case none
    var id: String { rawValue }
}

enum HeaderFooterElement: String, CaseIterable, Identifiable {
    case date = "Date"
    case pageNumber = "Page Number"
    case folder = "Folder"
    case projectName = "Project Name"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    var placeholder: String { "{{\(rawValue)}}" }
}

struct HeaderFooterDialog: View {
    let headerEnabled: Bool
    let footerEnabled: Bool
    @Binding var headerLeft: String
    @Binding var headerCenter: String
    @Binding var headerRight: String
    @Binding var footerLeft: String
    @Binding var footerCenter: String
    @Binding var footerRight: String
    @Binding var headerInsertTarget: HeaderFooterField
    @Binding var footerInsertTarget: HeaderFooterField
    @Binding var showHeaderElementPicker: Bool
    @Binding var showFooterElementPicker: Bool
    let headerFooterElements: [String]
    let onCancel: () -> Void
    let onSave: () -> Void
    
    @State private var headerSelectedElement: HeaderFooterElement = .date
    @State private var footerSelectedElement: HeaderFooterElement = .pageNumber

    var dialogTitle: String {
        if headerEnabled && footerEnabled { return NSLocalizedString("headerfooter.title.both", comment: "Page Header and Footer") }
        if headerEnabled { return NSLocalizedString("headerfooter.title.header", comment: "Page Header") }
        if footerEnabled { return NSLocalizedString("headerfooter.title.footer", comment: "Page Footer") }
        return NSLocalizedString("headerfooter.title.setup", comment: "Page Setup")
    }

    var body: some View {
        NavigationStack {
            Form {
                if headerEnabled {
                    headerSection
                }
                if footerEnabled {
                    footerSection
                }
            }
            .formStyle(.grouped)
            .navigationTitle(dialogTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) { onSave() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: headerEnabled && footerEnabled ? 340 : 200)
        #endif
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            LabeledContent(NSLocalizedString("headerfooter.field.left", comment: "Left Field:")) {
                TextField("", text: $headerLeft)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.centre", comment: "Centre Field:")) {
                TextField("", text: $headerCenter)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.right", comment: "Right Field:")) {
                TextField("", text: $headerRight)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 8) {
                Button(NSLocalizedString("headerfooter.button.add", comment: "Add")) {
                    insertElement(headerSelectedElement, isHeader: true)
                }
                .buttonStyle(.bordered)
                
                Picker("", selection: $headerSelectedElement) {
                    ForEach(HeaderFooterElement.allCases) { element in
                        Text(element.displayName).tag(element)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                
                Text("→")
                
                Picker("", selection: $headerInsertTarget) {
                    Text("Left").tag(HeaderFooterField.left)
                    Text("Centre").tag(HeaderFooterField.center)
                    Text("Right").tag(HeaderFooterField.right)
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        } header: {
            Text(NSLocalizedString("headerfooter.section.header", comment: "Header Fields"))
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        Section {
            LabeledContent(NSLocalizedString("headerfooter.field.left", comment: "Left Field:")) {
                TextField("", text: $footerLeft)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.centre", comment: "Centre Field:")) {
                TextField("", text: $footerCenter)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.right", comment: "Right Field:")) {
                TextField("", text: $footerRight)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 8) {
                Button(NSLocalizedString("headerfooter.button.add", comment: "Add")) {
                    insertElement(footerSelectedElement, isHeader: false)
                }
                .buttonStyle(.bordered)
                
                Picker("", selection: $footerSelectedElement) {
                    ForEach(HeaderFooterElement.allCases) { element in
                        Text(element.displayName).tag(element)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                
                Text("→")
                
                Picker("", selection: $footerInsertTarget) {
                    Text("Left").tag(HeaderFooterField.left)
                    Text("Centre").tag(HeaderFooterField.center)
                    Text("Right").tag(HeaderFooterField.right)
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        } header: {
            Text(NSLocalizedString("headerfooter.section.footer", comment: "Footer Fields"))
        }
    }
    
    // MARK: - Helper Methods
    
    private func insertElement(_ element: HeaderFooterElement, isHeader: Bool) {
        let placeholder = element.placeholder
        let target = isHeader ? headerInsertTarget : footerInsertTarget
        
        switch target {
        case .left:
            if isHeader { headerLeft += placeholder } else { footerLeft += placeholder }
        case .center:
            if isHeader { headerCenter += placeholder } else { footerCenter += placeholder }
        case .right:
            if isHeader { headerRight += placeholder } else { footerRight += placeholder }
        case .none:
            break
        }
    }
}
