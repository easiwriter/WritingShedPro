import SwiftUI

extension FolderFilesView {
    
    @ToolbarContentBuilder
    var folderToolbar: some ToolbarContent {
        // Using native iOS back button instead of custom PopToRootBackButton
        // Native back button is rendered by UIKit and immune to SwiftUI render blocking
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Settings gear for Front Matter / Back Matter folders
            if folder.isFrontMatterFolder {
                Button {
                    showFrontMatterSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(NSLocalizedString("frontMatter.settings.accessibility", comment: "Front Matter settings"))
                .help(NSLocalizedString("frontMatter.settings.help", comment: "Configure front matter items"))
            } else if folder.isBackMatterFolder {
                Button {
                    showBackMatterSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(NSLocalizedString("backMatter.settings.accessibility", comment: "Back Matter settings"))
                .help(NSLocalizedString("backMatter.settings.help", comment: "Configure back matter items"))
            }
            
            // Hide all other buttons for Front/Back Matter folders (except Edit for reordering)
            if !isMatterFolder {
                if !sortedFiles.isEmpty {
                    Button {
                        showSearchView = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search files in folder")
                    .help("Search and replace across all files")
                    .disabled(editMode == .active)
                }
                if FolderCapabilityService.canAddFile(to: folder) {
                    Button {
                        showImportPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import Word document")
                    .help("Import Word document")
                    .disabled(editMode == .active)
                }
                let enabled = headersOrFootersEnabled
                Button {
                    showHeaderFooterEditor = true
                } label: {
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                }
                .accessibilityLabel("Edit headers and footers")
                .help("Edit page headers and footers")
                .disabled(!enabled)
                .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                if FolderCapabilityService.canAddFile(to: folder) {
                    if isMixedContentFolder {
                        Menu {
                            Button {
                                showAddFileSheet = true
                            } label: {
                                Label(NSLocalizedString("folderFiles.addFile", comment: "Add File"), systemImage: "doc.badge.plus")
                            }
                            Button {
                                showAddFolderSheet = true
                            } label: {
                                Label(NSLocalizedString("folderFiles.addFolder", comment: "Add Folder"), systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderFiles.add.accessibility")
                        .disabled(editMode == .active)
                    } else {
                        Button {
                            showAddFileSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("folderFiles.addFile.accessibility")
                        .disabled(editMode == .active)
                    }
                }
            }
            
            // Edit/Done button for reordering (for all folders with files, including matter folders)
            if !sortedFiles.isEmpty || (isMixedContentFolder && !sortedSubfolders.isEmpty) {
                Button {
                    withAnimation {
                        editMode = editMode == .inactive ? .active : .inactive
                    }
                } label: {
                    Text(editMode == .inactive ? "button.edit" : "button.done")
                }
            }
        }
    }
}
