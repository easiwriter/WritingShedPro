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
    
    /// Optional caption prefix (e.g., "Figure", "Photo")
    var captionPrefix: String?
    
    /// Optional caption text
    var captionText: String?
    
    /// Caption style name (from stylesheet)
    var captionStyle: String?

    /// Vertical spacing in points around this image paragraph.
    var spacingAbove: CGFloat = 0
    var spacingBelow: CGFloat = 0
    
    /// Caption number (for numbered caption styles) - updated by document processing
    /// This is computed based on document order, not stored persistently
    var captionNumber: Int = 0
    
    /// Image style name (from stylesheet) - references an ImageStyle
    var imageStyleName: String = "default"
    
    /// File ID for accessing the correct stylesheet (for caption rendering)
    var fileID: UUID?
    
    /// Maximum width for images (prevents oversized images)
    static let maxWidth: CGFloat = 2048
    
    /// Fallback text-column width used only when the real container/text-view
    /// width is not yet known (e.g. before the attachment has been laid out).
    /// The actual display width is computed per-device from the live text
    /// container width at layout time — see `displaySize(forAvailableWidth:)`
    /// and the `attachmentBounds(for:...)` override. Sized for a standard
    /// A4/US Letter text column (page width minus ~1" margins).
    static let fallbackColumnWidth: CGFloat = 480
    
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
    
    /// Calculate display size using the fallback column width.
    /// Prefer `displaySize(forAvailableWidth:)` wherever the live text container
    /// width is known so the image is sized correctly for the current device.
    var displaySize: CGSize {
        return displaySize(forAvailableWidth: ImageAttachment.fallbackColumnWidth)
    }
    
    /// Calculate the on-screen display size of this image for a given available
    /// text-column width.
    ///
    /// The `scale` property is interpreted as a fraction of the available column
    /// width (1.0 == fill the column), NOT a fraction of the image's pixel size.
    /// This is what makes images render at a sensible size on every device and on
    /// the printed page: the same document opened on a phone, iPad or Mac fits its
    /// own text column instead of inheriting the pixel dimensions of whichever
    /// device first inserted the image. The image is never upscaled beyond its
    /// natural point size.
    /// - Parameter availableWidth: Width of the text column on the current device
    ///   (text container width minus line-fragment padding).
    func displaySize(forAvailableWidth availableWidth: CGFloat) -> CGSize {
        guard let image = image else {
            return CGSize(width: 300, height: 200) // Default size
        }
        
        let originalSize = image.size
        let column = (availableWidth.isFinite && availableWidth > 1)
            ? availableWidth
            : ImageAttachment.fallbackColumnWidth
        let aspectRatio = originalSize.height / max(originalSize.width, 1)
        
        // Apply the user's scale to the column width, but never exceed the image's
        // natural point width (no upscaling of small images).
        let width = min(column * scale, originalSize.width)
        var height = width * aspectRatio
        
        // Add caption height if caption is enabled
        if hasCaption, let captionText = captionText, !captionText.isEmpty {
            let captionHeight = estimateCaptionHeight(for: captionText, width: width)
            height += captionHeight + 4 // 4pt spacing between image and caption
        }
        
        return CGSize(width: width, height: height)
    }
    
    /// Resolve the available text-column width from a text container, falling back
    /// to the proposed line fragment and finally the fixed fallback width.
    static func availableWidth(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect = .zero) -> CGFloat {
        if let container = textContainer {
            let usable = container.size.width - container.lineFragmentPadding * 2
            if usable.isFinite && usable > 1 {
                return usable
            }
        }
        if lineFrag.width.isFinite && lineFrag.width > 1 {
            return lineFrag.width
        }
        return fallbackColumnWidth
    }
    
    /// Estimate caption height for bounds calculation
    private func estimateCaptionHeight(for text: String, width: CGFloat) -> CGFloat {
        var attributes: [NSAttributedString.Key: Any]
        
        if let fileID = fileID,
           let styleSheet = StyleSheetProvider.shared.styleSheet(for: fileID),
           let captionStyleName = captionStyle,
           let style = styleSheet.style(named: captionStyleName) {
            attributes = style.generateAttributes()
        } else {
            attributes = [.font: UIFont.systemFont(ofSize: 14)]
        }
        
        let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingRect = text.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(boundingRect.height)
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
        self.spacingAbove = max(0, CGFloat(coder.decodeDouble(forKey: "spacingAbove")))
        self.spacingBelow = max(0, CGFloat(coder.decodeDouble(forKey: "spacingBelow")))
        
        // Decode optional properties
        self.captionText = coder.decodeObject(of: NSString.self, forKey: "captionText") as? String
        self.captionPrefix = coder.decodeObject(of: NSString.self, forKey: "captionPrefix") as? String
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
        coder.encode(Double(spacingAbove), forKey: "spacingAbove")
        coder.encode(Double(spacingBelow), forKey: "spacingBelow")
        coder.encode(imageStyleName, forKey: "imageStyleName") // Not optional
        
        // Encode optional properties only if they exist
        if let captionText = captionText {
            coder.encode(captionText, forKey: "captionText")
        }
        if let captionPrefix = captionPrefix {
            coder.encode(captionPrefix, forKey: "captionPrefix")
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

    func paragraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        case .inline:
            paragraphStyle.alignment = .natural
        }
        paragraphStyle.paragraphSpacingBefore = max(0, spacingAbove)
        paragraphStyle.paragraphSpacing = max(0, spacingBelow)
        return paragraphStyle
    }
    
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
    func updateCaption(hasCaption: Bool, prefix: String?, text: String?, style: String?) {
        #if DEBUG
        print("🔵 ImageAttachment.updateCaption() - imageID: \(imageID), hasCaption: \(hasCaption), prefix: \(prefix ?? "nil"), text: \(text ?? "nil"), style: \(style ?? "nil")")
        #endif
        self.hasCaption = hasCaption
        self.captionPrefix = prefix
        self.captionText = text
        self.captionStyle = style
        notifyPropertiesChanged()
    }
    
    /// Notify observers that properties have changed
    private func notifyPropertiesChanged() {
        #if DEBUG
        print("📤 ImageAttachment.notifyPropertiesChanged() - Posting notification for imageID: \(imageID)")
        #endif
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
    
    /// TextKit asks the attachment for its bounds during layout. We compute the
    /// size from the LIVE text container width so the image fits the text column
    /// on the current device / printed page, regardless of which device inserted
    /// it. This drives both the editor (TextKit) and the paginated/print layout
    /// (NSLayoutManager + NSTextContainer).
    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
        let available = ImageAttachment.availableWidth(for: textContainer, proposedLineFragment: lineFrag)
        return CGRect(origin: .zero, size: displaySize(forAvailableWidth: available))
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
    
    // MARK: - Image Rendering (TextKit 1 Compatibility)
    
    /// Override image(forBounds:) to provide composite image with caption for TextKit 1
    /// This is needed because TextKit 1 mode doesn't use viewProvider
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        guard let baseImage = image ?? (imageData.flatMap { ImageAttachment.loadImage(from: $0) }) else {
            return nil
        }
        
        // If no caption, return the original image
        guard hasCaption else {
            return baseImage
        }
        
        // Build caption text with prefix
        let prefix = captionPrefix ?? ""
        let userCaptionText = captionText ?? ""
        let fullCaptionText = prefix.isEmpty ? userCaptionText : (userCaptionText.isEmpty ? prefix : "\(prefix) \(userCaptionText)")
        
        // If caption is effectively empty, return the original image
        guard !fullCaptionText.isEmpty else {
            return baseImage
        }
        
        // Create a composite image with caption below
        return createCompositeImage(baseImage: baseImage, captionText: fullCaptionText, bounds: imageBounds)
    }
    
    /// Create composite image with caption
    private func createCompositeImage(baseImage: UIImage, captionText: String, bounds: CGRect) -> UIImage? {
        // Get caption style attributes from stylesheet
        var attributes: [NSAttributedString.Key: Any]
        var finalCaptionText = captionText
        
        if let fileID = fileID,
           let styleSheet = StyleSheetProvider.shared.styleSheet(for: fileID),
           let captionStyleName = captionStyle,
           let style = styleSheet.style(named: captionStyleName) {
            // Use actual caption style from stylesheet
            attributes = style.generateAttributes()
            
            // Add caption number after prefix if style has numbering
            // captionText already contains "prefix userCaption" or just "userCaption"
            // We need to insert number after prefix
            if style.numberFormat != .none && captionNumber > 0 {
                let formattedNumber = style.numberFormat.symbol(for: captionNumber - 1, adornment: style.numberAdornment)
                let prefix = captionPrefix ?? ""
                let userCaption = self.captionText ?? ""
                
                // Build: prefix + number + userCaption
                var parts: [String] = []
                if !prefix.isEmpty { parts.append(prefix) }
                parts.append(formattedNumber)
                if !userCaption.isEmpty { parts.append(userCaption) }
                finalCaptionText = parts.joined(separator: " ")
            }
        } else {
            // Fallback styling if style not found
            let captionFont = UIFont.systemFont(ofSize: 14)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            attributes = [
                .font: captionFont,
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]
        }
        
        // Calculate caption height based on actual text rendering
        let maxSize = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        let boundingRect = finalCaptionText.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let captionHeight = ceil(boundingRect.height) + 4 // Add small padding
        
        let totalHeight = bounds.height + captionHeight
        let size = CGSize(width: bounds.width, height: totalHeight)
        
        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard UIGraphicsGetCurrentContext() != nil else { return nil }
        
        // Draw the image
        baseImage.draw(in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        
        // Draw the caption below
        let captionRect = CGRect(x: 0, y: bounds.height + 4, width: bounds.width, height: captionHeight)
        finalCaptionText.draw(in: captionRect, withAttributes: attributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Image Loading
    
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
    
    // MARK: - Caption Numbering
    
    /// Update caption numbers for all ImageAttachments in a text storage
    /// Call this after document loads or when attachments change
    /// - Parameters:
    ///   - textStorage: The text storage containing images
    ///   - styleSheet: The stylesheet to check for numbered caption styles
    static func updateCaptionNumbers(in textStorage: NSTextStorage, styleSheet: StyleSheet?) {
        guard let styleSheet = styleSheet else { return }
        
        // Track caption counts per style
        var captionCounters: [String: Int] = [:]
        
        // Enumerate all attachments in document order
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length), options: []) { value, _, _ in
            guard let imageAttachment = value as? ImageAttachment,
                  imageAttachment.hasCaption,
                  let captionStyleName = imageAttachment.captionStyle,
                  let captionStyle = styleSheet.style(named: captionStyleName),
                  captionStyle.numberFormat != .none else {
                return
            }
            
            // Increment counter for this caption style
            let counter = (captionCounters[captionStyleName] ?? 0) + 1
            captionCounters[captionStyleName] = counter
            
            // Update the attachment's caption number
            imageAttachment.captionNumber = counter
            
            #if DEBUG
            print("📷 Updated caption number: \(imageAttachment.imageID) -> \(counter) (style: \(captionStyleName))")
            #endif
        }
    }
    
    /// Update caption numbers for all ImageAttachments in an attributed string
    /// This is used before the attributed string is set to the text storage
    /// - Parameters:
    ///   - attributedString: The attributed string containing images
    ///   - styleSheet: The stylesheet to check for numbered caption styles
    static func updateCaptionNumbersInAttributedString(_ attributedString: NSAttributedString, styleSheet: StyleSheet?) {
        guard let styleSheet = styleSheet else {
            return
        }
        
        // Track caption counts per style
        var captionCounters: [String: Int] = [:]
        
        // Enumerate all attachments in document order
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length), options: []) { value, range, _ in
            guard let imageAttachment = value as? ImageAttachment else {
                return
            }
            
            guard imageAttachment.hasCaption,
                  let captionStyleName = imageAttachment.captionStyle,
                  let captionStyle = styleSheet.style(named: captionStyleName) else {
                return
            }
            
            guard captionStyle.numberFormat != .none else {
                return
            }
            
            // Increment counter for this caption style
            let counter = (captionCounters[captionStyleName] ?? 0) + 1
            captionCounters[captionStyleName] = counter
            
            // Update the attachment's caption number
            imageAttachment.captionNumber = counter
        }
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
