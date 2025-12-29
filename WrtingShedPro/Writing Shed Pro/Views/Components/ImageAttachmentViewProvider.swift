//
//  ImageAttachmentViewProvider.swift
//  Writing Shed Pro
//
//  Custom view provider for ImageAttachment that renders image with optional caption
//  Phase 006: Image Support - Caption feature
//

import UIKit

/// View provider that renders ImageAttachment with optional caption below
@available(iOS 15.0, *)
class ImageAttachmentViewProvider: NSTextAttachmentViewProvider {
    
    // MARK: - Properties
    
    /// The image attachment we're providing a view for
    private var imageAttachment: ImageAttachment? {
        return textAttachment as? ImageAttachment
    }
    
    /// File ID for accessing the correct stylesheet
    private var fileID: UUID?
    
    // MARK: - Initialization
    
    override init(textAttachment: NSTextAttachment, parentView: UIView?, textLayoutManager: NSTextLayoutManager?, location: NSTextLocation) {
        super.init(textAttachment: textAttachment, parentView: parentView, textLayoutManager: textLayoutManager, location: location)
        
        // Listen for stylesheet changes to refresh caption styling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStyleSheetModified(_:)),
            name: NSNotification.Name("StyleSheetModified"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProjectStyleSheetChanged(_:)),
            name: NSNotification.Name("ProjectStyleSheetChanged"),
            object: nil
        )
        
        // Listen for image property changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleImagePropertiesChanged(_:)),
            name: NSNotification.Name("ImageAttachmentPropertiesChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - View Creation
    
    override func loadView() {
        super.loadView()
        
        guard let imageAttachment = imageAttachment else {
            #if DEBUG
            print("⚠️ ImageAttachmentViewProvider: No image attachment")
            #endif
            return
        }
        
        #if DEBUG
        print("📷 ImageAttachmentViewProvider.loadView() called")
        #if DEBUG
        print("   hasCaption: \(imageAttachment.hasCaption)")
        #endif
        #if DEBUG
        print("   captionText: '\(imageAttachment.captionText ?? "nil")'")
        #endif
        #if DEBUG
        print("   captionStyle: \(imageAttachment.captionStyle ?? "nil")")
        #endif
        #if DEBUG
        print("   captionNumber: \(imageAttachment.captionNumber)")
        #endif
        #endif
        
        // Create the container view that will hold both image and caption
        let containerView = createContainerView(for: imageAttachment)
        self.view = containerView
    }
    
    // MARK: - View Creation Helpers
    
    private func createContainerView(for attachment: ImageAttachment) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .fill
        container.spacing = 4 // Small gap between image and caption
        container.distribution = .fill
        
        // Allow touch events to pass through to the text view for image selection
        container.isUserInteractionEnabled = false
        
        // Add image view
        if let image = attachment.image {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            imageView.isUserInteractionEnabled = false
            
            // Set image size based on attachment's displaySize
            let imageSize = attachment.displaySize
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            #if DEBUG
            print("📷 Image dimensions:")
            #if DEBUG
            print("   - image.size: \(image.size) (points)")
            #endif
            #if DEBUG
            print("   - image.scale: \(image.scale)")
            #endif
            #if DEBUG
            print("   - attachment.scale: \(attachment.scale)")
            #endif
            #if DEBUG
            print("   - displaySize: \(imageSize)")
            #endif
            #endif
            
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: imageSize.width),
                imageView.heightAnchor.constraint(equalToConstant: imageSize.height)
            ])
            
            container.addArrangedSubview(imageView)
            
            #if DEBUG
            print("📷 Added image view - size: \(imageSize)")
            #endif
        }
        
        // Add caption view if caption is enabled
        if attachment.hasCaption {
            let captionView = createCaptionView(for: attachment)
            container.addArrangedSubview(captionView)
            
            #if DEBUG
            print("📷 Added caption view")
            #endif
        }
        
        // Size the container
        container.translatesAutoresizingMaskIntoConstraints = false
        let containerSize = calculateContainerSize(for: attachment)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: containerSize.width),
            container.heightAnchor.constraint(equalToConstant: containerSize.height)
        ])
        
        return container
    }
    
    private func createCaptionView(for attachment: ImageAttachment) -> UIView {
        let captionLabel = UILabel()
        captionLabel.numberOfLines = 0 // Allow multiple lines
        captionLabel.lineBreakMode = .byWordWrapping
        
        // Get caption text
        var captionText = attachment.captionText ?? ""
        
        #if DEBUG
        print("📝 createCaptionView: captionText='\(captionText)', captionStyle=\(attachment.captionStyle ?? "nil"), captionNumber=\(attachment.captionNumber)")
        #endif
        
        // Apply caption style from stylesheet
        if let styleSheet = findStyleSheet(),
           let captionStyleName = attachment.captionStyle,
           let captionStyle = styleSheet.style(named: captionStyleName) {
            
            #if DEBUG
            print("📝 Found caption style '\(captionStyleName)' - numberFormat=\(captionStyle.numberFormat), captionNumber=\(attachment.captionNumber)")
            #endif
            
            // Check if the caption style has numbering enabled
            if captionStyle.numberFormat != .none && attachment.captionNumber > 0 {
                // Build the formatted number with parent prefix if applicable
                let formattedNumber = buildFormattedCaptionNumber(
                    for: attachment,
                    style: captionStyle,
                    styleSheet: styleSheet
                )
                captionText = "\(formattedNumber) \(captionText)"
                #if DEBUG
                print("📝 Added number prefix: '\(formattedNumber)' -> '\(captionText)'")
                #endif
            }
            
            let attributes = captionStyle.generateAttributes()
            captionLabel.attributedText = NSAttributedString(string: captionText, attributes: attributes)
            
            // Apply alignment relative to image bounds
            captionLabel.textAlignment = captionStyle.alignment
            
            #if DEBUG
            print("📝 Applied caption style '\(captionStyleName)' - alignment: \(captionStyle.alignment.rawValue), number: \(attachment.captionNumber)")
            #endif
        } else {
            // Fallback to simple styling if no style found
            captionLabel.text = captionText
            captionLabel.font = UIFont.systemFont(ofSize: 14)
            captionLabel.textColor = .secondaryLabel
            captionLabel.textAlignment = .center
            
            #if DEBUG
            print("⚠️ Caption style not found, using fallback")
            #endif
        }
        
        // Set width to match image width
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        let imageWidth = attachment.displaySize.width
        
        NSLayoutConstraint.activate([
            captionLabel.widthAnchor.constraint(equalToConstant: imageWidth)
        ])
        
        return captionLabel
    }
    
    private func calculateContainerSize(for attachment: ImageAttachment) -> CGSize {
        var height = attachment.displaySize.height
        let width = attachment.displaySize.width
        
        // Add caption height if present
        if attachment.hasCaption, let captionText = attachment.captionText, !captionText.isEmpty {
            // Estimate caption height
            let captionHeight = estimateCaptionHeight(
                text: captionText,
                width: width,
                styleName: attachment.captionStyle
            )
            height += 4 + captionHeight // spacing + caption
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func estimateCaptionHeight(text: String, width: CGFloat, styleName: String?) -> CGFloat {
        guard let styleSheet = findStyleSheet(),
              let styleName = styleName,
              let style = styleSheet.style(named: styleName) else {
            // Fallback estimation
            let font = UIFont.systemFont(ofSize: 14)
            let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let boundingRect = text.boundingRect(
                with: maxSize,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            return ceil(boundingRect.height)
        }
        
        // Use actual style font
        let attributes = style.generateAttributes()
        let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingRect = text.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        
        return ceil(boundingRect.height)
    }
    
    // MARK: - Caption Numbering
    
    /// Build the formatted caption number string with optional parent prefix
    private func buildFormattedCaptionNumber(for attachment: ImageAttachment, style: TextStyleModel, styleSheet: StyleSheet) -> String {
        let captionNumber = attachment.captionNumber
        
        // Check if this style has a parent for hierarchical numbering
        if let parentStyleName = style.parentStyleName,
           let parentStyle = styleSheet.style(named: parentStyleName),
           parentStyle.numberFormat != .none {
            // For hierarchical numbering, we'd need to track parent numbers
            // For now, just use the simple format until we have parent tracking
            // TODO: Implement hierarchical caption numbering
            return style.numberFormat.symbol(for: captionNumber - 1, adornment: style.numberAdornment)
        }
        
        // Standard format
        return style.numberFormat.symbol(for: captionNumber - 1, adornment: style.numberAdornment)
    }
    
    // MARK: - StyleSheet Access
    
    /// Find the stylesheet from the current context
    private func findStyleSheet() -> StyleSheet? {
        // Try to get fileID from the attachment first
        let fileID = self.fileID ?? imageAttachment?.fileID
        
        // Try to get from StyleSheetProvider using fileID if available
        if let fileID = fileID,
           let styleSheet = StyleSheetProvider.shared.styleSheet(for: fileID) {
            return styleSheet
        }
        
        // Fallback: try to get any active stylesheet
        return StyleSheetProvider.shared.anyActiveStyleSheet()
    }
    
    /// Set the file ID for accessing the correct stylesheet
    func setFileID(_ id: UUID) {
        self.fileID = id
        
        // Refresh view if already loaded
        if view != nil {
            refreshView()
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleStyleSheetModified(_ notification: Notification) {
        #if DEBUG
        print("📷 ImageAttachmentViewProvider: Received StyleSheetModified notification")
        #endif
        
        // Refresh the view to apply new styles
        refreshView()
    }
    
    @objc private func handleProjectStyleSheetChanged(_ notification: Notification) {
        #if DEBUG
        print("📷 ImageAttachmentViewProvider: Received ProjectStyleSheetChanged notification")
        #endif
        
        // Refresh the view to apply new styles
        refreshView()
    }
    
    @objc private func handleImagePropertiesChanged(_ notification: Notification) {
        // Check if this notification is for our attachment
        guard let imageID = notification.userInfo?["imageID"] as? UUID,
              let attachment = imageAttachment,
              attachment.imageID == imageID else {
            #if DEBUG
            print("📥 ImageAttachmentViewProvider: Ignoring notification (not for this attachment)")
            #endif
            return
        }
        
        #if DEBUG
        print("📥 ImageAttachmentViewProvider: Received notification for imageID: \(imageID)")
        #endif
        #if DEBUG
        print("   hasCaption: \(attachment.hasCaption), captionText: \(attachment.captionText ?? "nil")")
        #endif
        
        // Refresh the view to reflect new properties
        refreshView()
    }
    
    private func refreshView() {
        guard let attachment = imageAttachment else { return }
        
        #if DEBUG
        print("🔄 ImageAttachmentViewProvider.refreshView() - Recreating view")
        #endif
        
        // Recreate the view with updated properties
        let newView = createContainerView(for: attachment)
        
        // Replace the old view
        if let oldView = view {
            #if DEBUG
            print("   Removing old view")
            #endif
            oldView.removeFromSuperview()
        }
        
        self.view = newView
        #if DEBUG
        print("   New view set, size: \(newView.bounds.size)")
        #endif
        
        // Notify text view that layout needs update
        if let textView = view?.superview as? UITextView {
            #if DEBUG
            print("   Notifying text view to layout")
            #endif
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
        }
    }
}
