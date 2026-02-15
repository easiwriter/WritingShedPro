//
//  CoverImageEditorView.swift
//  Writing Shed Pro
//
//  View for editing cover image files (Front Cover / Back Cover).
//  Displays a single image with add/change/remove controls.
//  Cover files do not contribute to page count.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CoverImageEditorView: View {
    @Bindable var file: TextFile
    @State private var isProcessing = false
    @State private var showSourcePicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    if let imageData = file.coverImageData,
                       let uiImage = UIImage(data: imageData) {
                        coverImageContent(uiImage: uiImage, geometry: geometry)
                    } else {
                        emptyStateContent(geometry: geometry)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(file.name)
        .overlay {
            if isProcessing {
                ProgressView(NSLocalizedString("cover.processing", comment: "Processing..."))
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            NSLocalizedString("cover.chooseSource.title", comment: "Choose Image Source"),
            isPresented: $showSourcePicker,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("cover.chooseSource.photos", comment: "Photo Library")) {
                showPhotosPicker()
            }
            Button(NSLocalizedString("cover.chooseSource.files", comment: "Choose from Files")) {
                showFilePicker = true
            }
            Button(NSLocalizedString("button.cancel", comment: "Cancel"), role: .cancel) { }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentImagePicker { data in
                processImageData(data)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            isProcessing = true
            Task {
                await loadImage(from: item)
                selectedPhotoItem = nil
                isProcessing = false
            }
        }
    }
    
    // MARK: - Image Source Selection
    
    private func chooseImage() {
        #if targetEnvironment(macCatalyst)
        // Mac Catalyst: Photos library is not accessible, go directly to file picker
        showFilePicker = true
        #else
        // iOS: Let user choose between Photos and Files
        showSourcePicker = true
        #endif
    }
    
    private func showPhotosPicker() {
        // Present PHPicker via UIKit for reliable presentation
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        let delegate = PHPickerDelegateHandler { results in
            guard let result = results.first else { return }
            isProcessing = true
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        processImageData(data)
                    }
                } else {
                    DispatchQueue.main.async {
                        isProcessing = false
                    }
                }
            }
        }
        // Store delegate as associated object so it isn't deallocated
        objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        picker.delegate = delegate
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(picker, animated: true)
        }
    }
    
    // MARK: - Cover Image Content
    
    @ViewBuilder
    private func coverImageContent(uiImage: UIImage, geometry: GeometryProxy) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: geometry.size.width * 0.85)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            .padding(.top, 20)
        
        HStack(spacing: 16) {
            Button {
                chooseImage()
            } label: {
                Label(
                    NSLocalizedString("cover.changeImage", comment: "Change Image"),
                    systemImage: "photo.on.rectangle"
                )
            }
            
            Button(role: .destructive) {
                withAnimation {
                    file.coverImageData = nil
                }
            } label: {
                Label(
                    NSLocalizedString("cover.removeImage", comment: "Remove Image"),
                    systemImage: "trash"
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private func emptyStateContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("cover.noCoverImage", comment: "No cover image"))
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Button {
                chooseImage()
            } label: {
                Label(
                    NSLocalizedString("cover.addImage", comment: "Add Cover Image"),
                    systemImage: "plus.circle.fill"
                )
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, geometry.size.height * 0.25)
    }
    
    // MARK: - Image Processing
    
    private func processImageData(_ data: Data) {
        guard let uiImage = UIImage(data: data) else {
            isProcessing = false
            return
        }
        if let compressed = Self.compressImage(uiImage) {
            withAnimation {
                file.coverImageData = compressed
            }
        }
        isProcessing = false
    }
    
    private func loadImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }
        
        if let compressed = Self.compressImage(uiImage) {
            await MainActor.run {
                file.coverImageData = compressed
            }
        }
    }
    
    // MARK: - Image Compression
    
    /// Compress image to reasonable size for storage.
    /// Uses JPEG at 0.85 quality with a max width of 2048px.
    static func compressImage(_ image: UIImage, maxWidth: CGFloat = 2048) -> Data? {
        var scaledImage = image
        
        // Downscale if wider than maxWidth
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                scaledImage = resized
            }
            UIGraphicsEndImageContext()
        }
        
        // Try JPEG first (good for photos)
        if let jpegData = scaledImage.jpegData(compressionQuality: 0.85),
           jpegData.count < 1_000_000 {
            return jpegData
        }
        
        // Fall back to PNG (better for graphics)
        return scaledImage.pngData()
    }
}

// MARK: - PHPicker Delegate Handler

/// Standalone delegate class for PHPickerViewController used by CoverImageEditorView.
/// Stored as an associated object on the picker to prevent deallocation.
private class PHPickerDelegateHandler: NSObject, PHPickerViewControllerDelegate {
    private let completion: ([PHPickerResult]) -> Void
    
    init(completion: @escaping ([PHPickerResult]) -> Void) {
        self.completion = completion
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        completion(results)
    }
}

// MARK: - Document Image Picker

/// SwiftUI wrapper around UIDocumentPickerViewController for choosing images from Files.
struct DocumentImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImagePicked: (Data) -> Void
        let dismiss: DismissAction
        
        init(onImagePicked: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            
            if let data = try? Data(contentsOf: url) {
                onImagePicked(data)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}
