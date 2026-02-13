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

struct CoverImageEditorView: View {
    @Bindable var file: TextFile
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    
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
        .onChange(of: selectedItem) { _, newValue in
            guard let item = newValue else { return }
            isProcessing = true
            Task {
                await loadImage(from: item)
                selectedItem = nil
                isProcessing = false
            }
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
            PhotosPicker(selection: $selectedItem, matching: .images) {
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
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
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
    
    // MARK: - Image Loading
    
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
