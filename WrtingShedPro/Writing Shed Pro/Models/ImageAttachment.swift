//
//  ImageAttachment.swift
//  Writing Shed Pro
//
//  Custom NSTextAttachment for handling images in text documents
//  Supports scaling, alignment, and captions
//
//  **Design Note: Instance Properties vs Stylesheet Defaults**
//  Each ImageAttachment stores its own scale, alignment, and caption properties.
//  These are INSTANCE values that can be customized per image by the user.
//  - Initial values come from ImageStyle (stylesheet template)
//  - User edits are saved on this specific attachment
//  - Changing ImageStyle in stylesheet does NOT update existing images
//  This ensures user customizations are preserved across stylesheet changes.
//

import UIKit

/// Custom NSTextAttachment for handling images with advanced features
/// Each instance maintains its own scale, alignment, and caption settings
class ImageAttachment: NSTextAttachment, Identifiable {
    
    // MARK: - NSSecureCoding Support
    
    /// Declare support for NSSecureCoding to enable proper copy/paste
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    // MARK: - Identifiable
    
    var id: UUID { imageID }
    
    // MARK: - Properties
    
    /// Unique identifier for this image
    var imageID: UUID = UUID()
    
    /// Original image data (for persistence)
    var imageData: Data?
    
    /// Original filename when the image was imported (optional)
    var originalFilename: String?
    
    /// Scale percentage (0.1 to 2.0 = 10% to 200%)
    var scale: CGFloat = 1.0 {
        didSet {
            // Clamp scale to valid range
            scale = max(0.1, min(2.0, scale))
            updateBounds()
        }
    }
    
    /// Image alignment within text
    var alignment: ImageAlignment = .left
    
    /// Whether to show caption
    var hasCaption: Bool = false
    
    /// Optional caption text
    var captionText: String?
    
    /// Caption style name (from stylesheet)
    var captionStyle: String?
    
    /// Image style name (from stylesheet) - references an ImageStyle
    var imageStyleName: String = "default"
    
    /// File ID for accessing the correct stylesheet (for caption rendering)
    var fileID: UUID?
    
    /// Maximum width for images (prevents oversized images)
    static let maxWidth: CGFloat = 2048
    
    // MARK: - Helper Methods
    
    /// Load UIImage from data with proper scale for the device
    /// This ensures images display at the correct size (in points) on retina displays
    private static func loadImage(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        
        // If the image already has proper scale metadata, use it
        if image.scale > 1.0 {
            return image
        }
        
        // Otherwise, create a new UIImage with device scale
        // This ensures the image.size (in points) is correct for retina displays
        if let cgImage = image.cgImage {
            return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
    
    // MARK: - Alignment Enum
    
    enum ImageAlignment: String, Codable {
        case left
        case center
        case right
        case inline
    }
    
    // MARK: - Computed Properties
    
    /// Calculate display size based on original image size and scale
    var displaySize: CGSize {
        guard let image = image else {
            return CGSize(width: 300, height: 200) // Default size
        }
        
        let originalSize = image.size
        let width = originalSize.width * scale
        let height = originalSize.height * scale
        
        #if DEBUG
        // Only log if scale is unusual (< 0.5 or > 1.5)
        if scale < 0.5 || scale > 1.5 {
            print("🖼️ displaySize calc: originalSize=\(originalSize), scale=\(scale), result=\(CGSize(width: width, height: height))")
        }
        #endif
        
        return CGSize(width: width, height: height)
    }
    
    // MARK: - Initialization
    
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
        setupDefaults()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        // Decode our custom properties from the archive
        // If properties don't exist in the archive, use defaults
        if let imageIDString = coder.decodeObject(of: NSString.self, forKey: "imageID") as? String,
           let uuid = UUID(uuidString: imageIDString) {
            self.imageID = uuid
        } else {
            self.imageID = UUID()
        }
        
        self.scale = CGFloat(coder.decodeDouble(forKey: "scale"))
        if self.scale == 0 { self.scale = 1.0 } // Default if not found
        
        if let alignmentString = coder.decodeObject(of: NSString.self, forKey: "alignment") as? String,
           let decodedAlignment = ImageAlignment(rawValue: alignmentString) {
            self.alignment = decodedAlignment
        } else {
            self.alignment = .left
        }
        
        self.hasCaption = coder.decodeBool(forKey: "hasCaption")
        
        // Decode optional properties
        self.captionText = coder.decodeObject(of: NSString.self, forKey: "captionText") as? String
        self.captionStyle = coder.decodeObject(of: NSString.self, forKey: "captionStyle") as? String
        self.originalFilename = coder.decodeObject(of: NSString.self, forKey: "originalFilename") as? String
        
        // Decode imageStyleName - not optional, but provide default if missing
        if let styleName = coder.decodeObject(of: NSString.self, forKey: "imageStyleName") as? String {
            self.imageStyleName = styleName
        } else {
            self.imageStyleName = "default"
        }
        
        // Decode optional fileID
        if let fileIDString = coder.decodeObject(of: NSString.self, forKey: "fileID") as? String,
           let uuid = UUID(uuidString: fileIDString) {
            self.fileID = uuid
        }
        
        if let imageDataDecoded = coder.decodeObject(of: NSData.self, forKey: "imageData") as? Data {
            self.imageData = imageDataDecoded
            self.image = ImageAttachment.loadImage(from: imageDataDecoded)
        }
        
        updateBounds()
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        // Encode all our custom properties so they survive copy/paste
        coder.encode(imageID.uuidString, forKey: "imageID")
        coder.encode(Double(scale), forKey: "scale")
        coder.encode(alignment.rawValue, forKey: "alignment")
        coder.encode(hasCaption, forKey: "hasCaption")
        coder.encode(imageStyleName, forKey: "imageStyleName") // Not optional
        
        // Encode optional properties only if they exist
        if let captionText = captionText {
            coder.encode(captionText, forKey: "captionText")
        }
        if let captionStyle = captionStyle {
            coder.encode(captionStyle, forKey: "captionStyle")
        }
        if let originalFilename = originalFilename {
            coder.encode(originalFilename, forKey: "originalFilename")
        }
        if let imageData = imageData {
            coder.encode(imageData, forKey: "imageData")
        }
        if let fileID = fileID {
            coder.encode(fileID.uuidString, forKey: "fileID")
        }
    }
    
    convenience init() {
        self.init(data: nil, ofType: nil)
    }
    
    private func setupDefaults() {
        imageID = UUID()
        scale = 1.0
        alignment = .left
        hasCaption = false
        updateBounds()
    }
    
    // MARK: - Methods
    
    /// Set the scale for this image (0.1 to 2.0)
    func setScale(_ newScale: CGFloat) {
        scale = max(0.1, min(2.0, newScale))
    }
    
    /// Increment scale by 5%
    func incrementScale() {
        setScale(scale + 0.05)
    }
    
    /// Decrement scale by 5%
    func decrementScale() {
        setScale(scale - 0.05)
    }
    
    /// Set the alignment for this image
    func setAlignment(_ newAlignment: ImageAlignment) {
        alignment = newAlignment
    }
    
    /// Set caption text and style
    func setCaption(text: String?, style: String?) {
        captionText = text
        captionStyle = style
        hasCaption = text != nil && !text!.isEmpty
        notifyPropertiesChanged()
    }
    
    /// Enable or disable caption
    func setCaptionEnabled(_ enabled: Bool) {
        hasCaption = enabled
        notifyPropertiesChanged()
    }
    
    /// Update caption properties
    func updateCaption(hasCaption: Bool, text: String?, style: String?) {
        self.hasCaption = hasCaption
        self.captionText = text
        self.captionStyle = style
        notifyPropertiesChanged()
    }
    
    /// Notify observers that properties have changed
    private func notifyPropertiesChanged() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ImageAttachmentPropertiesChanged"),
            object: nil,
            userInfo: ["imageID": imageID]
        )
    }
    
    /// Update bounds based on current image and scale
    /// Update the bounds based on current scale and original image size
    func updateBounds() {
        bounds = CGRect(origin: .zero, size: displaySize)
    }
    
    /// Get scale as percentage string (e.g., "95.00 %")
    func scalePercentage() -> String {
        return String(format: "%.2f %%", scale * 100)
    }
    
    // MARK: - Static Methods
    
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
            
            #if os(macOS)
            // macOS implementation
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            newImage.unlockFocus()
            
            // Convert NSImage to data
            guard let tiffData = newImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData) else {
                return image.jpegData(compressionQuality: 0.85)
            }
            
            scaledImage = NSImage(data: bitmapImage.representation(using: .jpeg, properties: [:]) ?? Data()) ?? image as! UIImage
            #else
            // iOS implementation
            // Use 1.0 for scale to create smaller bitmap, then we'll restore proper scale in the UIImage
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let renderedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            
            // Create UIImage with proper scale factor for the device
            // This preserves the point-based size while keeping file size reasonable
            if let cgImage = renderedImage.cgImage {
                scaledImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: renderedImage.imageOrientation)
            } else {
                scaledImage = renderedImage
            }
            #endif
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
    
    /// Create ImageAttachment from image data
    static func from(imageData: Data, scale: CGFloat = 1.0, alignment: ImageAlignment = .left) -> ImageAttachment? {
        guard let image = loadImage(from: imageData) else {
            return nil
        }
        
        let attachment = ImageAttachment()
        attachment.imageData = imageData
        attachment.image = image
        attachment.scale = scale
        attachment.alignment = alignment
        attachment.updateBounds()
        
        return attachment
    }
    
    // MARK: - View Provider (iOS 15+)
    
    #if !os(macOS)
    /// Register custom view provider for rendering image with caption
    @available(iOS 15.0, *)
    override func viewProvider(for parentView: UIView?, location: NSTextLocation, textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
        return ImageAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
    #endif
}

// MARK: - Extension for UIImage/NSImage compatibility

#if os(macOS)
import AppKit
typealias UIImage = NSImage

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
#endif
