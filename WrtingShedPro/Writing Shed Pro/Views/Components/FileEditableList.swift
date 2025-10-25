import SwiftUI
import SwiftData

/// A specialized EditableList for File items
struct FileEditableList: View {
    @Environment(\.modelContext) private var modelContext
    let files: [File]
    @State private var selectedSortOrder: FileSortOrder
    @State private var isEditMode = false
    @State private var showDeleteConfirmation = false
    @State private var filesToDelete: IndexSet?
    
    // Sort and display state
    private var sortedFiles: [File] {
        FileSortService.sort(files, by: selectedSortOrder)
    }
    
    init(files: [File], initialSort: FileSortOrder = .byName) {
        self.files = files
        self._selectedSortOrder = State(initialValue: initialSort)
    }
    
    var body: some View {
        List {
            ForEach(sortedFiles) { file in
                NavigationLink(destination: FileDetailView(file: file)) {
                    FileItemView(file: file)
                }
            }
            .onDelete(perform: deleteFiles)
        }
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Custom Edit Button
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation {
                        isEditMode.toggle()
                    }
                }
                .disabled(files.isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                // Sort Menu
                Menu {
                    ForEach(FileSortService.sortOptions(), id: \.order) { option in
                        Button(action: {
                            selectedSortOrder = option.order
                        }) {
                            Label(option.title, systemImage: selectedSortOrder == option.order ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .onChange(of: files.isEmpty) { _, isEmpty in
            if isEmpty && isEditMode {
                withAnimation {
                    isEditMode = false
                }
            }
        }
        .confirmationDialog(
            "Delete Files",
            isPresented: $showDeleteConfirmation,
            presenting: filesToDelete,
            actions: { _ in
                Button("Delete", role: .destructive) {
                    confirmDeleteFiles()
                }
                Button("Cancel", role: .cancel) {
                    filesToDelete = nil
                }
            },
            message: { offsets in
                let count = offsets.count
                if count == 1 {
                    let fileName = sortedFiles[offsets.first ?? 0].name ?? "Untitled File"
                    return Text("Are you sure you want to delete \"\(fileName)\"? This action cannot be undone.")
                } else {
                    return Text("Are you sure you want to delete \(count) files? This action cannot be undone.")
                }
            }
        )
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        filesToDelete = offsets
        showDeleteConfirmation = true
    }
    
    private func confirmDeleteFiles() {
        guard let offsets = filesToDelete else { return }
        for index in offsets {
            let file = sortedFiles[index]
            modelContext.delete(file)
        }
        try? modelContext.save()
        filesToDelete = nil
    }
}

/// Helper view for displaying individual file items
struct FileItemView: View {
    let file: File
    
    private var fileIcon: String {
        let fileName = file.name ?? ""
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "txt", "md", "markdown":
            return "doc.text"
        case "rtf", "rtfd":
            return "doc.richtext"
        case "pdf":
            return "doc.text.fill"
        case "docx", "doc":
            return "doc"
        case "pages":
            return "doc.text.below.ecg"
        default:
            return "doc"
        }
    }
    
    private var fileSizeText: String {
        let contentLength = file.content?.count ?? 0
        if contentLength == 0 {
            return NSLocalizedString("file.empty", comment: "Empty")
        } else if contentLength < 1024 {
            return NSLocalizedString("file.bytes", comment: "\(contentLength) bytes")
        } else if contentLength < 1024 * 1024 {
            let kb = Double(contentLength) / 1024.0
            return String(format: NSLocalizedString("file.kilobytes", comment: "%.1f KB"), kb)
        } else {
            let mb = Double(contentLength) / (1024.0 * 1024.0)
            return String(format: NSLocalizedString("file.megabytes", comment: "%.1f MB"), mb)
        }
    }
    
    var body: some View {
        NavigationLink(destination: FileDetailView(file: file)) {
            HStack {
                Image(systemName: fileIcon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name ?? NSLocalizedString("file.untitled", comment: "Untitled File"))
                        .lineLimit(1)
                    
                    Text(fileSizeText)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Spacer()
            }
        }
    }
}