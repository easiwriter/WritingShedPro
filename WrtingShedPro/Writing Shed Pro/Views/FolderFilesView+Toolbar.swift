import SwiftUI

extension FolderFilesView {
    
    @ToolbarContentBuilder
    var folderToolbar: some ToolbarContent {
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
                // Collection expand/collapse button (Poetry content folders with collections)
                if isPoetryProject && isContentFolder && deferredPoetryCollectionGroups != nil {
                    collectionExpandCollapseToolbarButton
                }
                
                if !(deferredSortedFiles?.isEmpty ?? true) {
                    Button {
                        showSearchView = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search files in folder")
                    .help("Search and replace across all files")
                    .disabled(editMode == .active)
                }
                
                #if targetEnvironment(macCatalyst)
                // On Mac, show import and header/footer buttons directly in the toolbar
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
                let enabledMac = headersOrFootersEnabled
                Button {
                    if enabledMac {
                        showHeaderFooterEditor = true
                    } else {
                        showHeaderFooterWarning = true
                    }
                } label: {
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                }
                .accessibilityLabel("Edit headers and footers")
                .help("Edit page headers and footers")
                .foregroundStyle(enabledMac ? Color.accentColor : Color.secondary)
                #endif
                
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
            if !(deferredSortedFiles?.isEmpty ?? true) || (isMixedContentFolder && !sortedSubfolders.isEmpty) {
                Button {
                    withAnimation {
                        editMode = editMode == .inactive ? .active : .inactive
                    }
                } label: {
                    Text(editMode == .inactive ? "button.edit" : "button.done")
                }
            }
            
            #if !targetEnvironment(macCatalyst)
            // On iPhone/iPad, show overflow menu as rightmost button
            if !isMatterFolder {
                iPhoneOverflowMenu
            }
            #endif
        }
    }
    
    #if !targetEnvironment(macCatalyst)
    /// Overflow menu for iPhone/iPad showing import and header/footer options
    @ViewBuilder
    private var iPhoneOverflowMenu: some View {
        Menu {
            if FolderCapabilityService.canAddFile(to: folder) {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import Word document", systemImage: "square.and.arrow.down")
                }
            }
            Button {
                if headersOrFootersEnabled {
                    showHeaderFooterEditor = true
                } else {
                    showHeaderFooterWarning = true
                }
            } label: {
                Label("Edit headers and footers", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(editMode == .active)
    }
    #endif
    
    /// Expand/Collapse all button for collection-grouped view in Poetry content folders
    @ViewBuilder
    var collectionExpandCollapseToolbarButton: some View {
        let groups = deferredPoetryCollectionGroups ?? []
        let allExpanded = collectionExpandedSections.count == groups.count
        
        Button {
            withAnimation {
                if allExpanded {
                    collectionExpandedSections.removeAll()
                } else {
                    collectionExpandedSections = Set(groups.map { $0.id })
                }
            }
        } label: {
            Image(systemName: allExpanded ? "chevron.up.circle" : "chevron.down.circle")
        }
        .disabled(editMode == .active)
        .accessibilityLabel(Text(allExpanded ?
            NSLocalizedString("fileList.collapseAll", comment: "Collapse all") :
            NSLocalizedString("fileList.expandAll", comment: "Expand all")))
    }
}
