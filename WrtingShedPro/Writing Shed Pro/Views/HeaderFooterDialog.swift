
import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

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
    case collection = "Collection"
    case projectName = "Project Name"
    case author = "Author"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    var placeholder: String { "{{\(rawValue)}}" }
}

struct HeaderFooterDialog: View {
    @Environment(\.dismiss) private var dismiss
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
    @Binding var isPresented: Bool
    let headerFooterElements: [String]
    let onCancel: () -> Void
    let onSave: () -> Void
    
    // Local editing state – avoids propagating every keystroke back to
    // the (expensive) parent view.  Values are copied in on appear and
    // written back only on save.
    @State private var localHeaderLeft: String = ""
    @State private var localHeaderCenter: String = ""
    @State private var localHeaderRight: String = ""
    @State private var localFooterLeft: String = ""
    @State private var localFooterCenter: String = ""
    @State private var localFooterRight: String = ""
    @State private var localHeaderInsertTarget: HeaderFooterField = .left
    @State private var localFooterInsertTarget: HeaderFooterField = .left
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
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                        dismissSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        // Push local edits back to bindings before calling onSave
                        headerLeft = localHeaderLeft
                        headerCenter = localHeaderCenter
                        headerRight = localHeaderRight
                        footerLeft = localFooterLeft
                        footerCenter = localFooterCenter
                        footerRight = localFooterRight
                        headerInsertTarget = localHeaderInsertTarget
                        footerInsertTarget = localFooterInsertTarget
                        onSave()
                        dismissSheet()
                    }
                }
            }
            .onAppear {
                localHeaderLeft = headerLeft
                localHeaderCenter = headerCenter
                localHeaderRight = headerRight
                localFooterLeft = footerLeft
                localFooterCenter = footerCenter
                localFooterRight = footerRight
                localHeaderInsertTarget = headerInsertTarget
                localFooterInsertTarget = footerInsertTarget
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
                TextField("", text: $localHeaderLeft)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.centre", comment: "Centre Field:")) {
                TextField("", text: $localHeaderCenter)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.right", comment: "Right Field:")) {
                TextField("", text: $localHeaderRight)
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
                
                Picker("", selection: $localHeaderInsertTarget) {
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
                TextField("", text: $localFooterLeft)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.centre", comment: "Centre Field:")) {
                TextField("", text: $localFooterCenter)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent(NSLocalizedString("headerfooter.field.right", comment: "Right Field:")) {
                TextField("", text: $localFooterRight)
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
                
                Picker("", selection: $localFooterInsertTarget) {
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
        let target = isHeader ? localHeaderInsertTarget : localFooterInsertTarget
        
        switch target {
        case .left:
            if isHeader { localHeaderLeft += placeholder } else { localFooterLeft += placeholder }
        case .center:
            if isHeader { localHeaderCenter += placeholder } else { localFooterCenter += placeholder }
        case .right:
            if isHeader { localHeaderRight += placeholder } else { localFooterRight += placeholder }
        case .none:
            break
        }
    }

    private func dismissSheet() {
        isPresented = false
        dismiss()

        #if targetEnvironment(macCatalyst)
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController?
                .presentedViewController?
                .dismiss(animated: true)
        }
        #endif
    }
}
