import SwiftUI

struct OperatorRootView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case videos = "Videos"
        case messages = "Messages"
        case sales = "Sales"

        var id: Self { self }
    }

    @State private var settings = OperatorSettingsStore()
    @State private var selectedSection = Section.messages

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            switch selectedSection {
            case .videos:
            OperatorVideosView(settings: settings)
            case .messages:
            OperatorMessagesView(settings: settings)
            case .sales:
            OperatorSalesView(settings: settings)
            }
        }
    }
}
