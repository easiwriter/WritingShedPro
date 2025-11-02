# Phase 006: Image Support - Implementation Plan

## Overview
Detailed technical implementation plan for adding inline image support to Writing Shed Pro.

## Phase Breakdown

### Phase 1: Foundation (Days 1-2)

#### ImageAttachment Model
**File**: `WrtingShedPro/Writing Shed Pro/Models/ImageAttachment.swift`

```swift
import UIKit

/// Custom NSTextAttachment for handling images in text documents
class ImageAttachment: NSTextAttachment {
    
    // MARK: - Properties
    
    /// Unique identifier for this image
    var imageID: UUID = UUID()
    
    /// Original image data (for persistence)
    var imageData: Data?
    
    /// Current display size in points
    var displaySize: CGSize = .zero
    
    /// Image alignment within text
    var alignment: ImageAlignment = .left
    
    /// Maximum width for images (prevents oversized images)
    static let maxWidth: CGFloat = 2048
    
    // MARK: - Alignment
    
    enum ImageAlignment: String, Codable {
        case left
        case center
        case right
        case inline
    }
    
    // MARK: - Initialization
    
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
        setupDefaults()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDefaults()
    }
    
    private func setupDefaults() {
        imageID = UUID()
        alignment = .left
    }
    
    // MARK: - Methods
    
    /// Resize the image to a new size (maintains aspect ratio by default)
    func resize(to newSize: CGSize, maintainAspectRatio: Bool = true) {
        if maintainAspectRatio, let image = image {
            let aspectRatio = image.size.width / image.size.height
            let newHeight = newSize.width / aspectRatio
            displaySize = CGSize(width: newSize.width, height: newHeight)
        } else {
            displaySize = newSize
        }
        
        // Update bounds for UITextView
        bounds = CGRect(origin: .zero, size: displaySize)
    }
    
    /// Set the alignment for this image
    func setAlignment(_ newAlignment: ImageAlignment) {
        alignment = newAlignment
    }
    
    /// Calculate optimal display size for an image
    static func calculateDisplaySize(for image: UIImage, maxWidth: CGFloat = 600) -> CGSize {
        let width = min(image.size.width, maxWidth)
        let aspectRatio = image.size.width / image.size.height
        let height = width / aspectRatio
        return CGSize(width: width, height: height)
    }
    
    /// Compress image data if needed
    static func compressImage(_ image: UIImage, maxWidth: CGFloat = maxWidth) -> Data? {
        // Downscale if needed
        let scaledImage: UIImage
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            scaledImage = image
        }
        
        // Try JPEG compression first (better for photos)
        if let jpegData = scaledImage.jpegData(compressionQuality: 0.85),
           jpegData.count < 1_000_000 { // < 1MB
            return jpegData
        }
        
        // Fall back to PNG (better for graphics/screenshots)
        return scaledImage.pngData()
    }
}
```

#### Update AttributedStringSerializer
**File**: `WrtingShedPro/Writing Shed Pro/Services/AttributedStringSerializer.swift`

Add image serialization support:

```swift
// In encode() method, after handling colors:
if let attachment = value as? ImageAttachment {
    attributes.append([
        "type": "image",
        "location": i,
        "length": effectiveRange.length,
        "imageID": attachment.imageID.uuidString,
        "imageData": attachment.imageData?.base64EncodedString() ?? "",
        "width": attachment.displaySize.width,
        "height": attachment.displaySize.height,
        "alignment": attachment.alignment.rawValue
    ])
    
    print("💾 ENCODE image at \(i): id=\(attachment.imageID), size=\(attachment.displaySize)")
}

// In decode() method, after handling colors:
if attributeType == "image",
   let imageIDString = attrDict["imageID"] as? String,
   let imageID = UUID(uuidString: imageIDString),
   let imageDataString = attrDict["imageData"] as? String,
   let imageData = Data(base64Encoded: imageDataString),
   let width = attrDict["width"] as? CGFloat,
   let height = attrDict["height"] as? CGFloat,
   let alignmentString = attrDict["alignment"] as? String,
   let alignment = ImageAttachment.ImageAlignment(rawValue: alignmentString) {
    
    let attachment = ImageAttachment()
    attachment.imageID = imageID
    attachment.imageData = imageData
    attachment.image = UIImage(data: imageData)
    attachment.displaySize = CGSize(width: width, height: height)
    attachment.alignment = alignment
    attachment.bounds = CGRect(origin: .zero, size: attachment.displaySize)
    
    result.addAttribute(.attachment, value: attachment, range: range)
    
    print("💾 DECODE image at \(location): id=\(imageID), size=\(CGSize(width: width, height: height))")
}
```

### Phase 2: UI Integration (Days 3-4)

#### Add Toolbar Button
**File**: `WrtingShedPro/Writing Shed Pro/Views/FileEditView.swift`

Add after the color picker button:

```swift
// Image insertion button
Button(action: { showingImagePicker = true }) {
    Image(systemName: "photo.badge.plus")
        .font(.body)
        .help("Insert Image")
}
.disabled(file == nil)

// Add state variable
@State private var showingImagePicker = false

// Add file picker sheet
.fileImporter(
    isPresented: $showingImagePicker,
    allowedContentTypes: [.png, .jpeg, .heic, .gif],
    allowsMultipleSelection: false
) { result in
    handleImageSelection(result)
}

// Add handler method
private func handleImageSelection(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
        guard let url = urls.first else { return }
        insertImage(from: url)
    case .failure(let error):
        print("⚠️ Image picker error: \(error)")
    }
}

private func insertImage(from url: URL) {
    guard let file = file else { return }
    
    do {
        let imageData = try Data(contentsOf: url)
        guard let image = UIImage(data: imageData) else {
            print("⚠️ Could not load image from data")
            return
        }
        
        // Compress if needed
        let compressedData = ImageAttachment.compressImage(image) ?? imageData
        
        // Create command
        let command = InsertImageCommand(
            imageData: compressedData,
            location: currentSelection.location
        )
        
        // Execute
        command.execute(on: file, context: modelContext)
        file.addCommand(command)
        
        print("✅ Inserted image at position \(currentSelection.location)")
        
    } catch {
        print("⚠️ Error loading image: \(error)")
    }
}
```

#### Update FormattedTextEditor
**File**: `WrtingShedPro/Writing Shed Pro/Views/Components/FormattedTextEditor.swift`

Add image selection handling:

```swift
// Add property to track selected image
private var selectedImageAttachment: ImageAttachment?
private var selectedImageRange: NSRange?

// In textView(_:shouldChangeTextIn:replacementText:)
// Handle backspace on selected image
if text.isEmpty && selectedImageAttachment != nil {
    deleteSelectedImage()
    return false
}

// Add method to delete selected image
private func deleteSelectedImage() {
    guard let range = selectedImageRange,
          let file = /* get file reference */ else { return }
    
    let command = DeleteImageCommand(
        imageAttachment: selectedImageAttachment!,
        location: range.location
    )
    
    command.execute(on: file, context: modelContext)
    file.addCommand(command)
    
    selectedImageAttachment = nil
    selectedImageRange = nil
}

// Add gesture recognizer for image taps
private func setupImageTapGesture() {
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    textView.addGestureRecognizer(tapGesture)
}

@objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: textView)
    let position = textView.closestPosition(to: location)
    
    if let position = position {
        let offset = textView.offset(from: textView.beginningOfDocument, to: position)
        
        // Check if tapped on an attachment
        if offset < textView.textStorage.length {
            let attrs = textView.textStorage.attributes(at: offset, effectiveRange: nil)
            if let attachment = attrs[.attachment] as? ImageAttachment {
                selectImage(attachment, at: offset)
            } else {
                deselectImage()
            }
        }
    }
}

private func selectImage(_ attachment: ImageAttachment, at location: Int) {
    selectedImageAttachment = attachment
    selectedImageRange = NSRange(location: location, length: 1)
    
    // TODO: Show selection UI (border or highlight)
    print("🖼️ Selected image: \(attachment.imageID)")
}

private func deselectImage() {
    selectedImageAttachment = nil
    selectedImageRange = nil
}
```

### Phase 3: Undo/Redo Commands (Day 5)

#### InsertImageCommand
**File**: `WrtingShedPro/Writing Shed Pro/Models/Commands/InsertImageCommand.swift`

```swift
import Foundation
import SwiftData

struct InsertImageCommand: UndoableCommand {
    let id = UUID()
    let timestamp = Date()
    let commandDescription = "Insert Image"
    
    let imageData: Data
    let location: Int
    var displaySize: CGSize
    
    init(imageData: Data, location: Int) {
        self.imageData = imageData
        self.location = location
        
        // Calculate display size
        if let image = UIImage(data: imageData) {
            self.displaySize = ImageAttachment.calculateDisplaySize(for: image)
        } else {
            self.displaySize = CGSize(width: 300, height: 200)
        }
    }
    
    func execute(on file: File, context: ModelContext) {
        guard let attributedContent = file.attributedContent else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedContent)
        
        // Create attachment
        let attachment = ImageAttachment()
        attachment.imageData = imageData
        attachment.image = UIImage(data: imageData)
        attachment.displaySize = displaySize
        attachment.bounds = CGRect(origin: .zero, size: displaySize)
        
        // Insert into text
        let attachmentString = NSAttributedString(attachment: attachment)
        mutableText.insert(attachmentString, at: location)
        
        // Save
        file.formattedContent = AttributedStringSerializer.encode(mutableText)
        
        print("✅ Executed InsertImageCommand at \(location)")
    }
    
    func undo(on file: File, context: ModelContext) {
        guard let attributedContent = file.attributedContent else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedContent)
        
        // Remove the image (1 character for attachment)
        mutableText.deleteCharacters(in: NSRange(location: location, length: 1))
        
        // Save
        file.formattedContent = AttributedStringSerializer.encode(mutableText)
        
        print("↩️ Undid InsertImageCommand at \(location)")
    }
}
```

#### DeleteImageCommand
**File**: `WrtingShedPro/Writing Shed Pro/Models/Commands/DeleteImageCommand.swift`

```swift
struct DeleteImageCommand: UndoableCommand {
    let id = UUID()
    let timestamp = Date()
    let commandDescription = "Delete Image"
    
    let imageData: Data
    let location: Int
    let displaySize: CGSize
    let alignment: ImageAttachment.ImageAlignment
    
    init(imageAttachment: ImageAttachment, location: Int) {
        self.imageData = imageAttachment.imageData ?? Data()
        self.location = location
        self.displaySize = imageAttachment.displaySize
        self.alignment = imageAttachment.alignment
    }
    
    func execute(on file: File, context: ModelContext) {
        guard let attributedContent = file.attributedContent else { return }
        
        let mutableText = NSMutableAttributedString(attributedString: attributedContent)
        mutableText.deleteCharacters(in: NSRange(location: location, length: 1))
        
        file.formattedContent = AttributedStringSerializer.encode(mutableText)
        print("✅ Executed DeleteImageCommand at \(location)")
    }
    
    func undo(on file: File, context: ModelContext) {
        // Re-insert the image
        let insertCommand = InsertImageCommand(imageData: imageData, location: location)
        insertCommand.execute(on: file, context: context)
        
        print("↩️ Undid DeleteImageCommand at \(location)")
    }
}
```

### Phase 4: Testing (Day 6)

#### Unit Tests
**File**: `WrtingShedPro/WritingShedProTests/ImageAttachmentTests.swift`

```swift
import XCTest
@testable import Writing_Shed_Pro

final class ImageAttachmentTests: XCTestCase {
    
    func testImageAttachmentCreation() {
        let attachment = ImageAttachment()
        XCTAssertNotNil(attachment.imageID)
        XCTAssertEqual(attachment.alignment, .left)
    }
    
    func testResizeMaintainsAspectRatio() {
        // Create attachment with 200x100 image
        let image = createTestImage(width: 200, height: 100)
        let attachment = ImageAttachment()
        attachment.image = image
        
        // Resize to width 100
        attachment.resize(to: CGSize(width: 100, height: 0), maintainAspectRatio: true)
        
        // Should be 100x50
        XCTAssertEqual(attachment.displaySize.width, 100, accuracy: 0.1)
        XCTAssertEqual(attachment.displaySize.height, 50, accuracy: 0.1)
    }
    
    func testImageCompression() {
        let largeImage = createTestImage(width: 3000, height: 2000)
        let compressedData = ImageAttachment.compressImage(largeImage)
        
        XCTAssertNotNil(compressedData)
        XCTAssertLessThan(compressedData!.count, 2_000_000) // Less than 2MB
    }
    
    private func createTestImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
```

## Timeline Summary

- **Day 1-2**: Foundation (ImageAttachment + Serialization)
- **Day 3-4**: UI Integration (Toolbar + Editor)
- **Day 5**: Undo/Redo Commands
- **Day 6**: Testing
- **Total**: 6 days for MVP

## Next Steps After MVP

1. Add resize handles (macOS)
2. Add pinch gesture (iOS)
3. Add alignment controls
4. Add context menu
5. Add copy/paste support
6. Performance optimization
7. Comprehensive testing

---
**Status**: Ready for Implementation  
**Start Date**: TBD  
**Estimated Completion**: 6 working days
