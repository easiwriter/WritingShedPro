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
            print("⚠️ ImageAttachmentViewProvider: No image attachment")
            return
        }
        
        // Create the container view that will hold both image and caption
        let containerView = createContainerView(for: imageAttachment)
        self.view = containerView
        
        #if DEBUG
        print("📷 ImageAttachmentViewProvider.loadView() - hasCaption: \(imageAttachment.hasCaption), captionText: \(imageAttachment.captionText ?? "nil")")
        #endif
    }
    
    // MARK: - View Creation Helpers
    
    private func createContainerView(for attachment: ImageAttachment) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .fill
        container.spacing = 4 // Small gap between image and caption
        container.distribution = .fill
        
        // Add image view
        if let image = attachment.image {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            
            // Set image size based on attachment's displaySize
            let imageSize = attachment.displaySize
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            #if DEBUG
            print("📷 Image dimensions:")
            print("   - image.size: \(image.size) (points)")
            print("   - image.scale: \(image.scale)")
            print("   - attachment.scale: \(attachment.scale)")
            print("   - displaySize: \(imageSize)")
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
        let captionText = attachment.captionText ?? ""
        
        // Apply caption style from stylesheet
        if let styleSheet = findStyleSheet(),
           let captionStyleName = attachment.captionStyle,
           let captionStyle = styleSheet.style(named: captionStyleName) {
            
            let attributes = captionStyle.generateAttributes()
            captionLabel.attributedText = NSAttributedString(string: captionText, attributes: attributes)
            
            // Apply alignment relative to image bounds
            captionLabel.textAlignment = captionStyle.alignment
            
            #if DEBUG
            print("📝 Applied caption style '\(captionStyleName)' - alignment: \(captionStyle.alignment.rawValue)")
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
            print("📥 ImageAttachmentViewProvider: Ignoring notification (not for this attachment)")
            return
        }
        
        print("📥 ImageAttachmentViewProvider: Received notification for imageID: \(imageID)")
        print("   hasCaption: \(attachment.hasCaption), captionText: \(attachment.captionText ?? "nil")")
        
        // Refresh the view to reflect new properties
        refreshView()
    }
    
    private func refreshView() {
        guard let attachment = imageAttachment else { return }
        
        print("🔄 ImageAttachmentViewProvider.refreshView() - Recreating view")
        
        // Recreate the view with updated properties
        let newView = createContainerView(for: attachment)
        
        // Replace the old view
        if let oldView = view {
            print("   Removing old view")
            oldView.removeFromSuperview()
        }
        
        self.view = newView
        print("   New view set, size: \(newView.bounds.size)")
        
        // Notify text view that layout needs update
        if let textView = view?.superview as? UITextView {
            print("   Notifying text view to layout")
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
        }
    }
}
