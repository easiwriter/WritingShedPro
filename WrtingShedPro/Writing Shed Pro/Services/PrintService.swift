//
//  PrintService.swift
//  Writing Shed Pro
//
//  Coordinates printing operations
//  Presents native print dialogs and handles print jobs
//

import UIKit
import SwiftData

/// Service for coordinating printing operations
class PrintService {
    
    // MARK: - Single File Printing
    
    /// Print a single text file
    /// - Parameters:
    ///   - file: The text file to print
    ///   - project: The project (for stylesheet)
    ///   - context: Model context (for footnotes)
    ///   - viewController: The view controller to present the print dialog from
    ///   - completion: Called when printing completes or is cancelled
    static func printFile(
        _ file: TextFile,
        project: Project,
        context: ModelContext,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if DEBUG
        print("🖨️ [PrintService] Printing file: \(file.name)")
        #endif
        
        guard let content = file.currentVersion?.content else {
            #if DEBUG
            print("❌ [PrintService] No content in file")
            #endif
            completion(false, PrintError.noContent)
            return
        }
        
        // Get page setup
        let pageSetup = PageSetupPreferences.shared.createPageSetup()
        
        // Get attributed content and remove platform scaling
        let attributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(string: content)
        let printSizeContent = removePlatformScaling(from: attributedContent)
        
        // Present print dialog with custom renderer
        presentPrintDialog(
            file: file,
            content: printSizeContent,
            pageSetup: pageSetup,
            title: file.name,
            project: project,
            context: context,
            from: viewController,
            completion: completion
        )
    }
    
    // MARK: - Collection Printing
    
    /// Print an entire collection (multiple files)
    /// - Parameters:
    ///   - collection: The collection (Submission where publication is nil)
    ///   - modelContext: The model context for loading files
    ///   - viewController: The view controller to present the print dialog from
    ///   - completion: Called when printing completes or is cancelled
    static func printCollection(
        _ collection: Submission,
        modelContext: ModelContext,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if DEBUG
        print("🖨️ [PrintService] Printing collection: \(collection.name ?? "Untitled")")
        #endif
        
        // Get files from collection (through submittedFiles)
        let files = collection.submittedFiles?.compactMap { $0.textFile } ?? []
        let sortedFiles = files.sorted { $0.name < $1.name }
        
        guard !sortedFiles.isEmpty else {
            #if DEBUG
            print("❌ [PrintService] Collection is empty")
            #endif
            completion(false, PrintError.noContent)
            return
        }
        
        // Format multiple files
        guard let content = PrintFormatter.formatMultipleFiles(sortedFiles) else {
            #if DEBUG
            print("❌ [PrintService] Failed to format collection for printing")
            #endif
            completion(false, PrintError.noContent)
            return
        }
        
        // Get page setup
        let pageSetup = PageSetupPreferences.shared.createPageSetup()
        
        // Check if page breaks are enabled
        let usePageBreaks = PageSetupPreferences.shared.pageBreakBetweenFiles
        
        if usePageBreaks {
            // Use custom renderer for proper page break support
            #if DEBUG
            print("   - Using custom renderer for page breaks")
            #endif
            presentCustomRendererPrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: collection.name ?? "Collection",
                project: collection.project ?? sortedFiles.first?.project,
                from: viewController,
                completion: completion
            )
        } else {
            // Use simple formatter for continuous flow
            #if DEBUG
            print("   - Using simple formatter for continuous flow")
            #endif
            presentSimplePrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: collection.name ?? "Collection",
                from: viewController,
                completion: completion
            )
        }
    }
    
    // MARK: - Submission Printing
    
    /// Print an entire submission (multiple files)
    /// - Parameters:
    ///   - submission: The submission to print
    ///   - modelContext: The model context for loading files
    ///   - viewController: The view controller to present the print dialog from
    ///   - completion: Called when printing completes or is cancelled
    static func printSubmission(
        _ submission: Submission,
        modelContext: ModelContext,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        #if DEBUG
        print("🖨️ [PrintService] Printing submission: \(submission.publication?.name ?? submission.name ?? "Untitled")")
        #endif
        
        // Get files from submission (through submittedFiles)
        let files = submission.submittedFiles?.compactMap { $0.textFile } ?? []
        let sortedFiles = files.sorted { $0.name < $1.name }
        
        guard !sortedFiles.isEmpty else {
            #if DEBUG
            print("❌ [PrintService] Submission is empty")
            #endif
            completion(false, PrintError.noContent)
            return
        }
        
        // Format multiple files
        guard let content = PrintFormatter.formatMultipleFiles(sortedFiles) else {
            #if DEBUG
            print("❌ [PrintService] Failed to format submission for printing")
            #endif
            completion(false, PrintError.noContent)
            return
        }
        
        // Get page setup
        let pageSetup = PageSetupPreferences.shared.createPageSetup()
        
        // Check if page breaks are enabled
        let usePageBreaks = PageSetupPreferences.shared.pageBreakBetweenFiles
        
        if usePageBreaks {
            // Use custom renderer for proper page break support
            #if DEBUG
            print("   - Using custom renderer for page breaks")
            #endif
            presentCustomRendererPrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: submission.publication?.name ?? submission.name ?? "Submission",
                project: submission.project ?? sortedFiles.first?.project,
                from: viewController,
                completion: completion
            )
        } else {
            // Use simple formatter for continuous flow
            #if DEBUG
            print("   - Using simple formatter for continuous flow")
            #endif
            presentSimplePrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: submission.publication?.name ?? submission.name ?? "Submission",
                from: viewController,
                completion: completion
            )
        }
    }
    
    // MARK: - Print Dialog Presentation
    
    /// Present the native print dialog with prepared content
    /// - Parameters:
    ///   - file: The text file being printed
    ///   - content: The attributed string to print
    ///   - pageSetup: The page configuration
    ///   - title: The document title for the print job
    ///   - project: The project (for stylesheet)
    ///   - context: Model context (for footnotes)
    ///   - viewController: The view controller to present from
    ///   - completion: Called when printing completes or is cancelled
    private static func presentPrintDialog(
        file: TextFile,
        content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        project: Project,
        context: ModelContext,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // Create print interaction controller
        let printController = UIPrintInteractionController.shared
        
        // Configure print info
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = title
        printInfo.outputType = .general
        
        // Set orientation based on page setup
        let isLandscape = pageSetup.orientationEnum == .landscape
        printInfo.orientation = isLandscape ? .landscape : .portrait
        
        printController.printInfo = printInfo
        
        // Create text storage and layout manager using our pagination system
        // Use ORIGINAL font sizes to match pagination view line breaks
        let textStorage = NSTextStorage(attributedString: content)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout with footnote support
        let version = file.currentVersion
        let _ = layoutManager.calculateLayout(version: version, context: context)
        
        #if DEBUG
        print("🖨️ Print Dialog Setup:")
        #endif
        #if DEBUG
        print("   - Using CustomPDFPageRenderer with footnote support")
        #endif
        #if DEBUG
        print("   - Calculated pages: \(layoutManager.pageCount)")
        #endif
        
        // Create custom renderer
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            pageSetup: pageSetup,
            version: version,
            context: context,
            project: project
        )
        
        // Use the custom renderer instead of formatter
        printController.printPageRenderer = renderer
        
        // Show print preview
        printController.showsNumberOfCopies = true
        printController.showsPaperSelectionForLoadedPapers = true
        
        #if DEBUG
        print("   - Job name: \(title)")
        #endif
        #if DEBUG
        print("   - Orientation: \(isLandscape ? "landscape" : "portrait")")
        #endif
        #if DEBUG
        print("   - Paper size: \(pageSetup.paperSize.dimensions.width) x \(pageSetup.paperSize.dimensions.height)")
        #endif
        #if DEBUG
        print("   - Margins: T:\(pageSetup.marginTop) L:\(pageSetup.marginLeft) B:\(pageSetup.marginBottom) R:\(pageSetup.marginRight)")
        #endif
        
        // Present print dialog
        #if targetEnvironment(macCatalyst)
        // On Mac, present in a window
        printController.present(animated: true) { (controller, completed, error) in
            if let error = error {
                #if DEBUG
                print("❌ [PrintService] Print error: \(error.localizedDescription)")
                #endif
                completion(false, error)
            } else if completed {
                #if DEBUG
                print("✅ [PrintService] Print job completed")
                #endif
                completion(true, nil)
            } else {
                #if DEBUG
                print("⚠️ [PrintService] Print job cancelled")
                #endif
                completion(false, nil)
            }
        }
        #else
        // On iOS/iPad, present from view controller with popover support
        printController.present(from: viewController.view.bounds, in: viewController.view, animated: true) { (controller, completed, error) in
            if let error = error {
                #if DEBUG
                print("❌ [PrintService] Print error: \(error.localizedDescription)")
                #endif
                completion(false, error)
            } else if completed {
                #if DEBUG
                print("✅ [PrintService] Print job completed")
                #endif
                completion(true, nil)
            } else {
                #if DEBUG
                print("⚠️ [PrintService] Print job cancelled")
                #endif
                completion(false, nil)
            }
        }
        #endif
    }
    
    /// Present print dialog for multi-file content (collections/submissions)
    /// Uses simple formatter approach since there's no single version context
    /// - Parameters:
    ///   - content: The combined attributed string
    ///   - pageSetup: Page configuration
    ///   - title: Document title
    ///   - viewController: View controller to present from
    ///   - completion: Completion handler
    private static func presentSimplePrintDialog(
        content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // Create print interaction controller
        let printController = UIPrintInteractionController.shared
        
        // Configure print info
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = title
        printInfo.outputType = .general
        
        // Set orientation based on page setup
        let isLandscape = pageSetup.orientationEnum == .landscape
        printInfo.orientation = isLandscape ? .landscape : .portrait
        
        printController.printInfo = printInfo
        
        // Use simple formatter for multi-file content
        let formatter = UISimpleTextPrintFormatter(attributedText: content)
        formatter.maximumContentWidth = pageSetup.paperSize.dimensions.width - pageSetup.marginLeft - pageSetup.marginRight
        
        printController.printFormatter = formatter
        
        // Show print preview
        printController.showsNumberOfCopies = true
        printController.showsPaperSelectionForLoadedPapers = true
        
        #if DEBUG
        print("🖨️ Simple Print Dialog (Multi-file):")
        #endif
        #if DEBUG
        print("   - Job name: \(title)")
        #endif
        #if DEBUG
        print("   - Note: Using simple formatter (no footnote support for combined files)")
        #endif
        
        // Present print dialog
        #if targetEnvironment(macCatalyst)
        printController.present(animated: true) { (controller, completed, error) in
            if let error = error {
                #if DEBUG
                print("❌ [PrintService] Print error: \(error.localizedDescription)")
                #endif
                completion(false, error)
            } else if completed {
                #if DEBUG
                print("✅ [PrintService] Print job completed")
                #endif
                completion(true, nil)
            } else {
                #if DEBUG
                print("⚠️ [PrintService] Print job cancelled")
                #endif
                completion(false, nil)
            }
        }
        #else
        // On iOS/iPad, present from view controller with popover support
        printController.present(from: viewController.view.bounds, in: viewController.view, animated: true) { (controller, completed, error) in
            if let error = error {
                #if DEBUG
                print("❌ [PrintService] Print error: \(error.localizedDescription)")
                #endif
                completion(false, error)
            } else if completed {
                #if DEBUG
                print("✅ [PrintService] Print job completed")
                #endif
                completion(true, nil)
            } else {
                #if DEBUG
                print("⚠️ [PrintService] Print job cancelled")
                #endif
                completion(false, nil)
            }
        }
        #endif
    }
    
    /// Present print dialog with custom renderer for multi-file content with page breaks
    /// - Parameters:
    ///   - content: The combined attributed string
    ///   - pageSetup: Page configuration
    ///   - title: Document title
    ///   - project: Optional project (for stylesheet)
    ///   - viewController: View controller to present from
    ///   - completion: Completion handler
    private static func presentCustomRendererPrintDialog(
        content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        project: Project?,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let project = project else {
            #if DEBUG
            print("❌ [PrintService] No project available for custom renderer")
            #endif
            // Fall back to simple formatter
            presentSimplePrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: title,
                from: viewController,
                completion: completion
            )
            return
        }
        
        // Create print interaction controller
        let printController = UIPrintInteractionController.shared
        
        // Configure print info
        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = title
        printInfo.outputType = .general
        
        // Set orientation based on page setup
        let isLandscape = pageSetup.orientationEnum == .landscape
        printInfo.orientation = isLandscape ? .landscape : .portrait
        
        printController.printInfo = printInfo
        
        // Create text storage and layout manager using our pagination system
        let textStorage = NSTextStorage(attributedString: content)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (no version/context for multi-file - footnotes not supported)
        let _ = layoutManager.calculateLayout()
        
        #if DEBUG
        print("🖨️ Custom Renderer Print Dialog (Multi-file with page breaks):")
        #endif
        #if DEBUG
        print("   - Using CustomPDFPageRenderer for proper page break support")
        #endif
        #if DEBUG
        print("   - Calculated pages: \(layoutManager.pageCount)")
        #endif
        #if DEBUG
        print("   - Job name: \(title)")
        #endif
        
        // Create custom renderer
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            pageSetup: pageSetup,
            version: nil,  // No version for multi-file
            context: nil,  // No context for multi-file
            project: project
        )
        
        // Use the custom renderer
        printController.printPageRenderer = renderer
        
        // Show print preview
        printController.showsNumberOfCopies = true
        printController.showsPaperSelectionForLoadedPapers = true
        
        // Present print dialog
        #if targetEnvironment(macCatalyst)
        printController.present(animated: true) { (controller, completed, error) in
            if let error = error {
                #if DEBUG
                print("❌ [PrintService] Print error: \(error.localizedDescription)")
                #endif
                completion(false, error)
            } else if completed {
                #if DEBUG
                print("✅ [PrintService] Print job completed")
                #endif
                completion(true, nil)
            } else {
                #if DEBUG
                print("⚠️ [PrintService] Print job cancelled")
                #endif
                completion(false, nil)
            }
        }
        #else
        // On iOS/iPad, present from view controller with popover support
        printController.present(from: viewController.view.bounds, in: viewController.view, animated: true) { (controller, completed, error) in
            if let error = error {
                #if DEBUG
                print("❌ [PrintService] Print error: \(error.localizedDescription)")
                #endif
                completion(false, error)
            } else if completed {
                #if DEBUG
                print("✅ [PrintService] Print job completed")
                #endif
                completion(true, nil)
            } else {
                #if DEBUG
                print("⚠️ [PrintService] Print job cancelled")
                #endif
                completion(false, nil)
            }
        }
        #endif
    }
    
    // MARK: - PDF Generation
    
    /// Generate a PDF from a single file
    /// - Parameters:
    ///   - file: The text file to convert to PDF
    ///   - pageSetup: Optional page setup (defaults to preferences)
    ///   - project: The project (for stylesheet)
    ///   - context: Model context (for footnotes)
    /// - Returns: PDF data or nil if generation fails
    static func generatePDF(from file: TextFile, pageSetup: PageSetup? = nil, project: Project, context: ModelContext) -> Data? {
        #if DEBUG
        print("📄 [PrintService] Generating PDF for file: \(file.name)")
        #endif
        
        guard let content = file.currentVersion?.content else {
            #if DEBUG
            print("❌ [PrintService] No content in file")
            #endif
            return nil
        }
        
        let setup = pageSetup ?? PageSetupPreferences.shared.createPageSetup()
        
        // Get attributed content and remove platform scaling
        let attributedContent = file.currentVersion?.attributedContent ?? NSAttributedString(string: content)
        let printSizeContent = removePlatformScaling(from: attributedContent)
        
        return createPDF(
            from: printSizeContent,
            pageSetup: setup,
            title: file.name,
            version: file.currentVersion,
            project: project,
            context: context
        )
    }
    
    /// Generate a PDF from multiple files (collection or submission)
    /// - Parameters:
    ///   - files: Array of text files to combine into PDF
    ///   - title: Document title for metadata
    ///   - pageSetup: Optional page setup (defaults to preferences)
    ///   - project: The project (for stylesheet)
    ///   - context: Model context (for footnotes)
    /// - Returns: PDF data or nil if generation fails
    static func generatePDF(from files: [TextFile], title: String, pageSetup: PageSetup? = nil, project: Project, context: ModelContext) -> Data? {
        #if DEBUG
        print("📄 [PrintService] Generating PDF for \(files.count) files: \(title)")
        #endif
        
        guard let content = PrintFormatter.formatMultipleFiles(files) else {
            #if DEBUG
            print("❌ [PrintService] Failed to format files for PDF")
            #endif
            return nil
        }
        
        let setup = pageSetup ?? PageSetupPreferences.shared.createPageSetup()
        
        // For multiple files, we don't have a single version context
        // This is a limitation - multi-file PDFs won't include footnotes yet
        return createPDF(
            from: content,
            pageSetup: setup,
            title: title,
            version: nil,
            project: project,
            context: context
        )
    }
    
    /// Save a PDF file to the app's Documents directory
    /// - Parameters:
    ///   - data: The PDF data to save
    ///   - filename: The filename (without extension)
    /// - Returns: URL of saved PDF or nil if save fails
    static func savePDF(_ data: Data, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pdfURL = documentsPath.appendingPathComponent("\(filename).pdf")
        
        do {
            try data.write(to: pdfURL)
            #if DEBUG
            print("✅ [PrintService] PDF saved to: \(pdfURL.path)")
            #endif
            return pdfURL
        } catch {
            #if DEBUG
            print("❌ [PrintService] Failed to save PDF: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// Share a PDF using the system share sheet
    /// - Parameters:
    ///   - data: The PDF data to share
    ///   - filename: The filename for the PDF
    ///   - viewController: The view controller to present the share sheet from
    static func sharePDF(_ data: Data, filename: String, from viewController: UIViewController) {
        guard let url = savePDF(data, filename: filename) else {
            #if DEBUG
            print("❌ [PrintService] Failed to save PDF for sharing")
            #endif
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // For iPad: present from a specific point
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true)
        #if DEBUG
        print("📤 [PrintService] Sharing PDF: \(filename)")
        #endif
    }
    
    // MARK: - Private PDF Creation
    
    /// Create PDF data from attributed string using our custom pagination system
    /// - Parameters:
    ///   - content: The attributed string to render
    ///   - pageSetup: Page configuration
    ///   - title: Document title for metadata
    ///   - version: Optional version for footnote support
    ///   - project: Project for stylesheet
    ///   - context: Model context for footnote queries
    /// - Returns: PDF data or nil if creation fails
    private static func createPDF(
        from content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        version: Version?,
        project: Project,
        context: ModelContext
    ) -> Data? {
        #if DEBUG
        print("🖨️ PDF Generation Setup:")
        #endif
        #if DEBUG
        print("   - Paper: \(pageSetup.paperSize.dimensions.width) x \(pageSetup.paperSize.dimensions.height)")
        #endif
        #if DEBUG
        print("   - Margins: T:\(pageSetup.marginTop) L:\(pageSetup.marginLeft) B:\(pageSetup.marginBottom) R:\(pageSetup.marginRight)")
        #endif
        #if DEBUG
        print("   - Has version for footnotes: \(version != nil)")
        #endif
        
        // Create text storage from content
        let textStorage = NSTextStorage(attributedString: content)
        
        // Create layout manager using our pagination system
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (with footnote support if version provided)
        let _ = layoutManager.calculateLayout(version: version, context: context)
        #if DEBUG
        print("   - Calculated: \(layoutManager.pageCount) pages")
        #endif
        
        guard layoutManager.pageCount > 0 else {
            #if DEBUG
            print("❌ [PrintService] No pages to render")
            #endif
            return nil
        }
        
        // Create custom renderer
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            pageSetup: pageSetup,
            version: version,
            context: context,
            project: project
        )
        
        // Create PDF data
        let pdfData = NSMutableData()
        let paperSize = pageSetup.paperSize.dimensions
        let paperRect = CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height)
        
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Writing Shed Pro"
        ])
        
        // Render each page
        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            
            let bounds = UIGraphicsGetPDFContextBounds()
            renderer.drawPage(at: pageIndex, in: bounds)
        }
        
        UIGraphicsEndPDFContext()
        
        #if DEBUG
        print("✅ [PrintService] PDF created: \(renderer.numberOfPages) pages")
        #endif
        return pdfData as Data
    }
    
    // MARK: - Font Scaling Helper
    
    /// Remove platform-specific font scaling to get actual print size
    /// Database contains Mac-rendered fonts (22.1pt), both platforms need to scale down for print
    private static func removePlatformScaling(from attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if let font = value as? UIFont {
                // Reverse the 1.3x scaling from Mac's generateFont()
                // Database: 22.1pt → Print: 17pt (÷1.3)
                let printSize = font.pointSize / 1.3
                let printFont = font.withSize(printSize)
                mutable.addAttribute(.font, value: printFont, range: range)
            }
        }
        
        return mutable
    }
    
    // MARK: - Utility Methods
    
    /// Check if printing is available on this device
    /// - Returns: True if printing is supported
    static func isPrintingAvailable() -> Bool {
        return UIPrintInteractionController.isPrintingAvailable
    }
    
    /// Check if a specific file can be printed
    /// - Parameter file: The file to check
    /// - Returns: True if the file has printable content
    static func canPrint(file: TextFile) -> Bool {
        guard let content = PrintFormatter.formatFile(file) else {
            return false
        }
        return PrintFormatter.isValidForPrinting(content)
    }
}

// MARK: - Print Errors

enum PrintError: LocalizedError {
    case noContent
    case notAvailable
    case cancelled
    case failed(String)
    
    var errorDescription: String? {
        switch self {
        case .noContent:
            return NSLocalizedString("print.error.noContent", value: "No content to print", comment: "No content to print")
        case .notAvailable:
            return NSLocalizedString("print.error.notAvailable", value: "Printing is not available", comment: "Printing is not available")
        case .cancelled:
            return NSLocalizedString("print.error.cancelled", value: "Printing was cancelled", comment: "Printing was cancelled")
        case .failed(let message):
            return String(format: NSLocalizedString("print.error.failed", value: "Print failed: %@", comment: "Print failed: %@"), message)
        }
    }
}
