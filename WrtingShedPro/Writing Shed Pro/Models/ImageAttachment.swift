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
class ImageAttachment: NSTextAttachment {
    
    // MARK: - NSSecureCoding Support
    
    /// Declare support for NSSecureCoding to enable proper copy/paste
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    // MARK: - Properties
    
    /// Unique identifier for this image
    var imageID: UUID = UUID()
    
    /// Original image data (for persistence)
    var imageData: Data?
    
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
    
    /// Maximum width for images (prevents oversized images)
    static let maxWidth: CGFloat = 2048
    
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
        
        // Decode imageStyleName - not optional, but provide default if missing
        if let styleName = coder.decodeObject(of: NSString.self, forKey: "imageStyleName") as? String {
            self.imageStyleName = styleName
        } else {
            self.imageStyleName = "default"
        }
        
        if let imageDataDecoded = coder.decodeObject(of: NSData.self, forKey: "imageData") as? Data {
            self.imageData = imageDataDecoded
            self.image = UIImage(data: imageDataDecoded)
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
        if let imageData = imageData {
            coder.encode(imageData, forKey: "imageData")
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
    }
    
    /// Enable or disable caption
    func setCaptionEnabled(_ enabled: Bool) {
        hasCaption = enabled
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
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
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
        guard let image = UIImage(data: imageData) else {
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
