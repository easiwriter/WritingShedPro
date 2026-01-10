import SwiftUI
import SwiftData

/// View displaying the assembled manuscript body content (Feature 029)
/// This shows a virtual view of content assembled from source folders (Poems, Scenes, Scripts, Sections)
struct ManuscriptBodyView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // Placeholder content until Phase 2 implementation
            Section {
                ContentUnavailableView {
                    Label("manuscript.body.comingSoon", systemImage: "doc.on.doc")
                } description: {
                    Text("manuscript.body.comingSoonDescription")
                }
            }
        }
        .navigationTitle(NSLocalizedString("folder.body", comment: "Body"))
        .navigationBarBackButtonHidden(true)
        .onPopToRoot {
            dismiss()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopToRootBackButton()
            }
        }
    }
}
