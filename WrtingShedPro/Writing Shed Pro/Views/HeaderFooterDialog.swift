
import SwiftUI

enum HeaderFooterField: String, CaseIterable, Identifiable {
    case left
    case center
    case right
    case none
    var id: String { rawValue }
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

    var dialogTitle: String {
        if headerEnabled && footerEnabled { return "Page Header and Footer" }
        if headerEnabled { return "Page Header" }
        if footerEnabled { return "Page Footer" }
        return "Page Setup"
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(dialogTitle).font(.headline)
            if headerEnabled {
                VStack(spacing: 12) {
                    Text("Header Fields").font(.subheadline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Left Field:")
                            TextField("", text: $headerLeft)
                        }
                        VStack(alignment: .leading) {
                            Text("Centre Field:")
                            TextField("", text: $headerCenter)
                        }
                        VStack(alignment: .leading) {
                            Text("Right Field:")
                            TextField("", text: $headerRight)
                        }
                    }
                    HStack {
                        Button("Add") { showHeaderElementPicker = true }
                        Picker("To:", selection: $headerInsertTarget) {
                            Text("Left Field").tag(HeaderFooterField.left)
                            Text("Centre Field").tag(HeaderFooterField.center)
                            Text("Right Field").tag(HeaderFooterField.right)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    if showHeaderElementPicker {
                        Picker("Insert Element", selection: .constant("")) {
                            ForEach(headerFooterElements, id: \ .self) { el in
                                Button(el) {
                                    switch headerInsertTarget {
                                    case .left: headerLeft += "{{" + el + "}}"
                                    case .center: headerCenter += "{{" + el + "}}"
                                    case .right: headerRight += "{{" + el + "}}"
                                    default: break
                                    }
                                    showHeaderElementPicker = false
                                }
                            }
                        }
                    }
                }
                Divider()
            }
            if footerEnabled {
                VStack(spacing: 12) {
                    Text("Footer Fields").font(.subheadline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Left Field:")
                            TextField("", text: $footerLeft)
                        }
                        VStack(alignment: .leading) {
                            Text("Centre Field:")
                            TextField("", text: $footerCenter)
                        }
                        VStack(alignment: .leading) {
                            Text("Right Field:")
                            TextField("", text: $footerRight)
                        }
                    }
                    HStack {
                        Button("Add") { showFooterElementPicker = true }
                        Picker("To:", selection: $footerInsertTarget) {
                            Text("Left Field").tag(HeaderFooterField.left)
                            Text("Centre Field").tag(HeaderFooterField.center)
                            Text("Right Field").tag(HeaderFooterField.right)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    if showFooterElementPicker {
                        Picker("Insert Element", selection: .constant("")) {
                            ForEach(headerFooterElements, id: \ .self) { el in
                                Button(el) {
                                    switch footerInsertTarget {
                                    case .left: footerLeft += "{{" + el + "}}"
                                    case .center: footerCenter += "{{" + el + "}}"
                                    case .right: footerRight += "{{" + el + "}}"
                                    default: break
                                    }
                                    showFooterElementPicker = false
                                }
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Save") { onSave() }
            }
        }
        .padding()
        .frame(minWidth: 420)
    }
}
