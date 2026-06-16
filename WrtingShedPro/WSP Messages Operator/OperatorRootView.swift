import SwiftUI

struct OperatorRootView: View {
    @State private var settings = OperatorSettingsStore()

    var body: some View {
        TabView {
            OperatorVideosView(settings: settings)
                .tabItem {
                    Label("Videos", systemImage: "film")
                }

            OperatorMessagesView(settings: settings)
                .tabItem {
                    Label("Messages", systemImage: "text.bubble")
                }
        }
    }
}
