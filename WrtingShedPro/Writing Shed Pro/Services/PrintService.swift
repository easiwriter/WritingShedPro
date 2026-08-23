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
    
    // MARK: - Multiple Files Printing
    
    /// Print multiple text files as a single combined document
    /// - Parameters:
    ///   - files: The text files to print
    ///   - project: The project (for stylesheet)
    ///   - context: Model context
    ///   - viewController: The view controller to present the print dialog from
    ///   - completion: Called when printing completes or is cancelled
    static func printFiles(
        _ files: [TextFile],
        project: Project,
        context: ModelContext,
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // Single file: use standard single-file print path
        if files.count == 1, let file = files.first {
            printFile(file, project: project, context: context, from: viewController, completion: completion)
            return
        }
        
        #if DEBUG
        print("🖨️ [PrintService] Printing \(files.count) files")
        #endif
        
        guard !files.isEmpty else {
            completion(false, PrintError.noContent)
            return
        }
        
        // Format multiple files
        guard let content = PrintFormatter.formatMultipleFiles(files) else {
            #if DEBUG
            print("❌ [PrintService] Failed to format files for printing")
            #endif
            completion(false, PrintError.noContent)
            return
        }
        
        // Get page setup
        let pageSetup = PageSetupPreferences.shared.createPageSetup()
        
        // Check if page breaks are enabled
        let usePageBreaks = PageSetupPreferences.shared.pageBreakBetweenFiles
        
        let title = files.count == 1 ? files[0].name : "\(project.name ?? "Project") (\(files.count) files)"
        
        if usePageBreaks {
            presentCustomRendererPrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: title,
                project: project,
                from: viewController,
                completion: completion
            )
        } else {
            presentSimplePrintDialog(
                content: content,
                pageSetup: pageSetup,
                title: title,
                from: viewController,
                completion: completion
            )
        }
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
        FootnoteAttachment.reconcileMarkerStyles(in: textStorage, stylesheet: project.styleSheet)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout with footnote support
        let version = file.currentVersion
        let layoutResult = layoutManager.calculateLayout(version: version, context: context)
        
        #if DEBUG
        print("🖨️ Print Dialog Setup:")
        #endif
        #if DEBUG
        print("   - Using CustomPDFPageRenderer with footnote support")
        #endif
        #if DEBUG
        print("   - Calculated pages: \(layoutResult.totalPages)")
        #endif
        
        // Create custom renderer
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            layoutResult: layoutResult,
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
        FootnoteAttachment.reconcileMarkerStyles(in: textStorage, stylesheet: project.styleSheet)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (no version/context for multi-file - footnotes not supported)
        let layoutResult = layoutManager.calculateLayout()
        
        #if DEBUG
        print("🖨️ Custom Renderer Print Dialog (Multi-file with page breaks):")
        #endif
        #if DEBUG
        print("   - Using CustomPDFPageRenderer for proper page break support")
        #endif
        #if DEBUG
        print("   - Calculated pages: \(layoutResult.totalPages)")
        #endif
        #if DEBUG
        print("   - Job name: \(title)")
        #endif
        
        // Create custom renderer
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            layoutResult: layoutResult,
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
    
    /// Generate a PDF from manuscript content (Feature 029)
    /// - Parameters:
    ///   - content: The assembled manuscript content
    ///   - project: The project
    ///   - pageSetup: Optional page setup (defaults to preferences)
    ///   - context: Model context (for footnotes)
    /// - Returns: PDF data or nil if generation fails
    static func generatePDF(from content: ManuscriptContent, project: Project, pageSetup: PageSetup? = nil, context: ModelContext) -> Data? {
        #if DEBUG
        print("📄 [PrintService] Generating PDF for manuscript: \(project.name ?? "Untitled")")
        #endif
        
        guard content.attributedString.length > 0 else {
            #if DEBUG
            print("❌ [PrintService] Manuscript content is empty")
            #endif
            return nil
        }
        
        let setup = pageSetup ?? PageSetupPreferences.shared.createPageSetup()
        
        // Remove platform scaling from content
        let printSizeContent = removePlatformScaling(from: content.attributedString)
        
        return createPDF(
            from: printSizeContent,
            pageSetup: setup,
            title: project.name ?? "Manuscript",
            version: nil,
            project: project,
            context: context,
            hasFrontCover: content.hasFrontCover,
            hasBackCover: content.hasBackCover,
            frontMatterFileCount: content.frontMatterFileCount,
            frontMatterCharacterLength: content.frontMatterCharacterLength,
            assembledFootnotes: content.assembledFootnotes,
            frontCoverImageData: content.frontCoverImageData,
            backCoverImageData: content.backCoverImageData,
            fileCollectionMap: content.fileCollectionMap
        )
    }
    
    /// Generate a PDF from manuscript content with page rendering progress reporting.
    /// Runs heavy work on a background queue so the caller can await without blocking the UI.
    /// - Parameters:
    ///   - content: The assembled manuscript content
    ///   - project: The project
    ///   - pageSetup: Optional page setup (defaults to preferences)
    ///   - context: Model context (for footnotes)
    ///   - progress: Callback with (currentPage, totalPages) fired after each page is rendered
    /// - Returns: PDF data or nil if generation fails
    static func generatePDFWithProgress(
        from content: ManuscriptContent,
        project: Project,
        pageSetup: PageSetup? = nil,
        context: ModelContext,
        layoutProgress: @escaping @Sendable (Int, Int) -> Void,
        renderProgress: @escaping @Sendable (Int, Int) -> Void
    ) async -> Data? {
        #if DEBUG
        print("📄 [PrintService] Generating PDF with progress for: \(project.name ?? "Untitled")")
        #endif
        
        guard content.attributedString.length > 0 else {
            #if DEBUG
            print("❌ [PrintService] Manuscript content is empty")
            #endif
            return nil
        }
        
        let setup = pageSetup ?? PageSetupPreferences.shared.createPageSetup()
        let printSizeContent = removePlatformScaling(from: content.attributedString)
        
        // Transfer non-Sendable values to the background queue.
        // SwiftData models and contexts remain confined to the executor that created them.
        nonisolated(unsafe) let bgContent = printSizeContent
        nonisolated(unsafe) let bgSetup = setup
        let projectID = project.id
        let projectName = project.name ?? "Manuscript"
        let modelContainer = context.container
        let bgHasFrontCover = content.hasFrontCover
        let bgHasBackCover = content.hasBackCover
        let bgFrontMatterFileCount = content.frontMatterFileCount
        let bgFrontMatterCharacterLength = content.frontMatterCharacterLength
        let bgAssembledFootnotes = content.assembledFootnotes
        let bgFrontCoverImageData = content.frontCoverImageData
        let bgBackCoverImageData = content.backCoverImageData
        let bgCenteredChunks = content.verticallyCenteredChunkIndices
        let bgFileCollectionMap = content.fileCollectionMap
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderContext = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate<Project> { project in
                        project.id == projectID
                    }
                )
                guard let renderProject = try? renderContext.fetch(descriptor).first else {
                    continuation.resume(returning: nil)
                    return
                }

                let result = createPDFWithProgress(
                    from: bgContent,
                    pageSetup: bgSetup,
                    title: projectName,
                    version: nil,
                    project: renderProject,
                    context: renderContext,
                    layoutProgress: layoutProgress,
                    renderProgress: renderProgress,
                    hasFrontCover: bgHasFrontCover,
                    hasBackCover: bgHasBackCover,
                    frontMatterFileCount: bgFrontMatterFileCount,
                    frontMatterCharacterLength: bgFrontMatterCharacterLength,
                    assembledFootnotes: bgAssembledFootnotes,
                    frontCoverImageData: bgFrontCoverImageData,
                    backCoverImageData: bgBackCoverImageData,
                    verticallyCenteredChunkIndices: bgCenteredChunks,
                    fileCollectionMap: bgFileCollectionMap
                )
                continuation.resume(returning: result)
            }
        }
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
            activityItems: [ShareActivityItemSource(url: url, facebookText: "Shared from Writing Shed Pro: \(url.lastPathComponent)")],
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
        context: ModelContext,
        hasFrontCover: Bool = false,
        hasBackCover: Bool = false,
        frontMatterFileCount: Int = 0,
        frontMatterCharacterLength: Int = 0,
        assembledFootnotes: [ManuscriptFootnote] = [],
        frontCoverImageData: Data? = nil,
        backCoverImageData: Data? = nil,
        fileCollectionMap: [(offset: Int, collectionName: String)] = []
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
        FootnoteAttachment.reconcileMarkerStyles(in: textStorage, stylesheet: project.styleSheet)
        NumberingLayoutManager.ensureNumberIndents(in: textStorage, styleSheet: project.styleSheet)
        
        // Create layout manager using our pagination system
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        // Calculate layout (with footnote support if version provided or assembled footnotes exist)
        // IMPORTANT: Use the returned result directly, not layoutManager.pageCount,
        // because the property update happens async and won't be ready yet
        let layoutResult: PaginatedTextLayoutManager.LayoutResult
        if version != nil {
            layoutResult = layoutManager.calculateLayout(version: version, context: context)
        } else if !assembledFootnotes.isEmpty {
            layoutResult = layoutManager.calculateLayout(assembledFootnotes: assembledFootnotes)
        } else {
            layoutResult = layoutManager.calculateLayout()
        }
        #if DEBUG
        print("   - Calculated: \(layoutResult.totalPages) pages")
        #endif
        
        guard layoutResult.totalPages > 0 else {
            #if DEBUG
            print("❌ [PrintService] No pages to render")
            #endif
            return nil
        }
        
        // Create custom renderer with the layout result
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            layoutResult: layoutResult,
            pageSetup: pageSetup,
            version: version,
            context: context,
            project: project,
            hasFrontCover: hasFrontCover,
            hasBackCover: hasBackCover,
            frontMatterCharacterLength: frontMatterCharacterLength,
            assembledFootnotes: assembledFootnotes,
            frontCoverImageData: frontCoverImageData,
            backCoverImageData: backCoverImageData,
            fileCollectionMap: fileCollectionMap
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
    
    /// Create PDF with per-page progress reporting (called from a background queue)
    private static func createPDFWithProgress(
        from content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        version: Version?,
        project: Project,
        context: ModelContext,
        layoutProgress: @escaping (Int, Int) -> Void,
        renderProgress: @escaping (Int, Int) -> Void,
        hasFrontCover: Bool = false,
        hasBackCover: Bool = false,
        frontMatterFileCount: Int = 0,
        frontMatterCharacterLength: Int = 0,
        assembledFootnotes: [ManuscriptFootnote] = [],
        frontCoverImageData: Data? = nil,
        backCoverImageData: Data? = nil,
        verticallyCenteredChunkIndices: Set<Int> = [],
        fileCollectionMap: [(offset: Int, collectionName: String)] = []
    ) -> Data? {
        #if DEBUG
        print("🖨️ PDF Generation (with progress) Setup:")
        print("   - Paper: \(pageSetup.paperSize.dimensions.width) x \(pageSetup.paperSize.dimensions.height)")
        #endif
        
        // FAST PATH: When there are no footnotes, split at form feed characters
        // and render each page independently. This is O(n) instead of O(n²)
        // because it avoids the slow multi-container NSLayoutManager layout.
        let textString = content.string
        let hasFootnotes = version != nil || !assembledFootnotes.isEmpty
        let hasImages = containsImageAttachments(in: content)
        if !hasFootnotes && !hasImages && textString.contains("\u{000C}") {
            #if DEBUG
            print("   ⚡ Using FAST PATH (form-feed split, no footnotes)")
            #endif
            // Ensure numbered heading paragraphs have firstLineHeadIndent for number space
            let adjustedContent = NSMutableAttributedString(attributedString: content)
            NumberingLayoutManager.ensureNumberIndents(in: adjustedContent, styleSheet: project.styleSheet)
            return createPDFWithFormFeedSplit(
                from: adjustedContent,
                pageSetup: pageSetup,
                title: title,
                project: project,
                hasFrontCover: hasFrontCover,
                hasBackCover: hasBackCover,
                frontMatterFileCount: frontMatterFileCount,
                frontCoverImageData: frontCoverImageData,
                backCoverImageData: backCoverImageData,
                verticallyCenteredChunkIndices: verticallyCenteredChunkIndices,
                fileCollectionMap: fileCollectionMap,
                progress: { current, total in
                    // Report as layout progress for the first 90%, render for the last 10%
                    // In practice each page is laid out + rendered in one step
                    layoutProgress(current, total)
                    if current == total {
                        renderProgress(current, total)
                    }
                }
            )
        }
        
        // STANDARD PATH: Full layout calculation for footnote-aware rendering
        let textStorage = NSTextStorage(attributedString: content)
        FootnoteAttachment.reconcileMarkerStyles(in: textStorage, stylesheet: project.styleSheet)
        NumberingLayoutManager.ensureNumberIndents(in: textStorage, styleSheet: project.styleSheet)
        let layoutManager = PaginatedTextLayoutManager(
            textStorage: textStorage,
            pageSetup: pageSetup
        )
        
        let layoutResult: PaginatedTextLayoutManager.LayoutResult
        if version != nil {
            layoutResult = layoutManager.calculateLayout(version: version, context: context, layoutProgress: layoutProgress)
        } else if !assembledFootnotes.isEmpty {
            layoutResult = layoutManager.calculateLayout(assembledFootnotes: assembledFootnotes, layoutProgress: layoutProgress)
        } else {
            layoutResult = layoutManager.calculateLayout(layoutProgress: layoutProgress)
        }
        let totalPages = layoutResult.totalPages
        #if DEBUG
        print("   - Calculated: \(totalPages) pages")
        #endif
        
        guard totalPages > 0 else {
            #if DEBUG
            print("❌ [PrintService] No pages to render")
            #endif
            return nil
        }
        
        // Signal layout complete so the bar reaches 95% before rendering starts
        layoutProgress(totalPages, totalPages)
        renderProgress(0, totalPages)
        
        let renderer = CustomPDFPageRenderer(
            layoutManager: layoutManager,
            layoutResult: layoutResult,
            pageSetup: pageSetup,
            version: version,
            context: context,
            project: project,
            hasFrontCover: hasFrontCover,
            hasBackCover: hasBackCover,
            frontMatterCharacterLength: frontMatterCharacterLength,
            assembledFootnotes: assembledFootnotes,
            frontCoverImageData: frontCoverImageData,
            backCoverImageData: backCoverImageData,
            fileCollectionMap: fileCollectionMap
        )
        
        let pdfData = NSMutableData()
        let paperSize = pageSetup.paperSize.dimensions
        let paperRect = CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height)
        
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Writing Shed Pro"
        ])
        
        let totalRenderPages = renderer.numberOfPages
        for pageIndex in 0..<totalRenderPages {
            UIGraphicsBeginPDFPage()
            let bounds = UIGraphicsGetPDFContextBounds()
            renderer.drawPage(at: pageIndex, in: bounds)
            
            // Report render progress every 5 pages (throttle to avoid flooding main actor)
            let done = pageIndex + 1
            if done % 5 == 0 || done == totalRenderPages {
                renderProgress(done, totalRenderPages)
            }
        }
        
        UIGraphicsEndPDFContext()
        
        #if DEBUG
        print("✅ [PrintService] PDF created with progress: \(renderer.numberOfPages) pages")
        #endif
        return pdfData as Data
    }
    
    // MARK: - Fast-Path PDF (Form Feed Split)
    
    /// Fast PDF generation for documents that use form feed page breaks and have no footnotes.
    /// Splits the attributed string at \u{000C} characters and renders each chunk independently,
    /// avoiding the O(n²) multi-container NSLayoutManager layout entirely.
    private static func createPDFWithFormFeedSplit(
        from content: NSAttributedString,
        pageSetup: PageSetup,
        title: String,
        project: Project,
        hasFrontCover: Bool = false,
        hasBackCover: Bool = false,
        frontMatterFileCount: Int = 0,
        frontCoverImageData: Data? = nil,
        backCoverImageData: Data? = nil,
        verticallyCenteredChunkIndices: Set<Int> = [],
        fileCollectionMap: [(offset: Int, collectionName: String)] = [],
        progress: @escaping (Int, Int) -> Void
    ) -> Data? {
        let fullString = content.string as NSString
        let totalLength = fullString.length
        
        // Split at form feed characters to find section boundaries
        var chunkRanges: [NSRange] = []
        var start = 0
        while start < totalLength {
            let searchRange = NSRange(location: start, length: totalLength - start)
            let ffRange = fullString.range(of: "\u{000C}", options: [], range: searchRange)
            if ffRange.location != NSNotFound {
                chunkRanges.append(NSRange(location: start, length: ffRange.location - start))
                start = ffRange.location + 1  // Skip the form feed
            } else {
                // Last chunk (no trailing form feed)
                chunkRanges.append(NSRange(location: start, length: totalLength - start))
                break
            }
        }
        
        // Remove empty trailing chunks (e.g. if text ends with a form feed)
        while let last = chunkRanges.last, last.length == 0, chunkRanges.count > 1 {
            chunkRanges.removeLast()
        }
        
        guard !chunkRanges.isEmpty else {
            #if DEBUG
            print("❌ [PrintService] No chunks after form-feed split")
            #endif
            return nil
        }
        
        let pageLayout = PageLayoutCalculator.calculateLayout(from: pageSetup)
        let contentRect = pageLayout.contentRect
        let containerSize = contentRect.size
        let paperSize = pageSetup.paperSize.dimensions
        let paperRect = CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height)
        
        // Sub-paginate each chunk independently using a lightweight per-chunk layout.
        // Each chunk gets its own NSLayoutManager so we never have hundreds of containers
        // in a single manager (which causes the O(n²) slowdown).
        // For poetry (1 poem = 1 chunk ≤ 1 page) this adds negligible overhead.
        // For novels (1 chapter = 1 chunk = many pages) this correctly flows text.
        struct PageSlice {
            let chunkIndex: Int
            let attributedString: NSMutableAttributedString
            let characterRange: NSRange  // range within the chunk's text storage
        }
        
        var allPages: [PageSlice] = []
        
        for (chunkIndex, chunkRange) in chunkRanges.enumerated() {
            let chunkAttrString: NSAttributedString
            if chunkRange.length > 0 {
                chunkAttrString = content.attributedSubstring(from: chunkRange)
            } else {
                chunkAttrString = NSAttributedString(string: "")
            }
            let chunkMutable = NSMutableAttributedString(attributedString: chunkAttrString)
            prepareAttributedStringForPDF(chunkMutable)
            
            // For empty chunks, emit one blank page
            guard chunkMutable.length > 0 else {
                allPages.append(PageSlice(
                    chunkIndex: chunkIndex,
                    attributedString: chunkMutable,
                    characterRange: NSRange(location: 0, length: 0)
                ))
                continue
            }
            
            // Sub-paginate: use a fresh layout manager to find page breaks within this chunk
            let chunkStorage = NSTextStorage(attributedString: chunkMutable)
            let chunkLM = NSLayoutManager()
            chunkStorage.addLayoutManager(chunkLM)
            
            var charIdx = 0
            while charIdx < chunkStorage.length {
                let container = NSTextContainer(size: containerSize)
                container.lineFragmentPadding = 0
                chunkLM.addTextContainer(container)
                
                let glyphRange = chunkLM.glyphRange(for: container)
                let charRange = chunkLM.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                
                allPages.append(PageSlice(
                    chunkIndex: chunkIndex,
                    attributedString: chunkMutable,
                    characterRange: charRange
                ))
                
                if charRange.length > 0 {
                    charIdx = NSMaxRange(charRange)
                } else {
                    break  // Safety: no progress
                }
                
                if charIdx >= chunkStorage.length { break }
            }
            
            // Report progress based on chunks processed (gives early estimates)
            if (chunkIndex + 1) % 5 == 0 || chunkIndex == chunkRanges.count - 1 {
                // Rough page estimate scales linearly with chunks processed
                let estimatedTotal = max(allPages.count, allPages.count * chunkRanges.count / (chunkIndex + 1))
                progress(allPages.count, estimatedTotal)
            }
        }
        
        let totalPages = allPages.count
        guard totalPages > 0 else {
            #if DEBUG
            print("❌ [PrintService] No pages after sub-pagination")
            #endif
            return nil
        }
        
        #if DEBUG
        print("   ⚡ Form-feed split: \(chunkRanges.count) chunks → \(totalPages) pages")
        #endif
        
        // Render all pages
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "Writing Shed Pro"
        ])
        
        // Determine which pages are cover pages (no headers/footers, no page number)
        let lastPageIndex = totalPages - 1
        
        // Determine which chunk indices are front matter.
        // Chunk order: [front cover (optional)] [front matter files] [body files] [back matter files] [back cover (optional)]
        let firstFMChunkIndex = hasFrontCover ? 1 : 0
        let lastFMChunkIndex = firstFMChunkIndex + frontMatterFileCount - 1  // inclusive; -1 when no FM
        
        // Pre-calculate the number of pages in each numbering region.
        // Front matter pages get roman numerals (1-based), body+back get arabic (1-based).
        let coverPageCount = (hasFrontCover ? 1 : 0) + (hasBackCover ? 1 : 0)
        let frontMatterTotalPages = allPages.filter { page in
            page.chunkIndex >= firstFMChunkIndex && page.chunkIndex <= lastFMChunkIndex
        }.count
        let bodyTotalPages = totalPages - coverPageCount - frontMatterTotalPages
        
        // Track running page numbers for each region independently
        var frontMatterPageCounter = 0
        var bodyPageCounter = 0
        
        // Track running paragraph numbering counters across pages
        var fastPathStyleCounters: [String: Int] = [:]
        var fastPathLastNumberForStyle: [String: Int] = [:]
        
        for (pageIndex, slice) in allPages.enumerated() {
            UIGraphicsBeginPDFPage()
            
            guard let cgContext = UIGraphicsGetCurrentContext() else { continue }
            
            // Skip headers/footers on cover pages
            let isFrontCoverPage = hasFrontCover && pageIndex == 0
            let isBackCoverPage = hasBackCover && pageIndex == lastPageIndex
            let isCoverPage = isFrontCoverPage || isBackCoverPage
            
            // Determine if this page is front matter
            let isFrontMatterPage = frontMatterFileCount > 0
                && slice.chunkIndex >= firstFMChunkIndex
                && slice.chunkIndex <= lastFMChunkIndex
            
            if !isCoverPage {
                // Calculate page number string: roman for front matter, arabic for body
                let pageNumberString: String
                let displayTotalPages: Int
                if isFrontMatterPage {
                    frontMatterPageCounter += 1
                    pageNumberString = toRomanNumeral(frontMatterPageCounter)
                    displayTotalPages = frontMatterTotalPages
                } else {
                    bodyPageCounter += 1
                    pageNumberString = "\(bodyPageCounter)"
                    displayTotalPages = bodyTotalPages
                }
                
                // Draw headers
                if pageSetup.hasHeaders, let headerRect = pageLayout.headerRect {
                    drawHeaderFooter(
                        left: pageSetup.headerLeft,
                        center: pageSetup.headerCenter,
                        right: pageSetup.headerRight,
                        rect: headerRect,
                        pageNumberString: pageNumberString,
                        totalPages: displayTotalPages,
                        project: project,
                        fileCollectionMap: fileCollectionMap,
                        pageCharOffset: chunkRanges[slice.chunkIndex].location,
                        context: cgContext
                    )
                }
                
                // Draw footers
                if pageSetup.hasFooters, let footerRect = pageLayout.footerRect {
                    drawHeaderFooter(
                        left: pageSetup.footerLeft,
                        center: pageSetup.footerCenter,
                        right: pageSetup.footerRight,
                        rect: footerRect,
                        pageNumberString: pageNumberString,
                        totalPages: displayTotalPages,
                        project: project,
                        fileCollectionMap: fileCollectionMap,
                        pageCharOffset: chunkRanges[slice.chunkIndex].location,
                        context: cgContext
                    )
                }
            }
            
            // Draw cover image or text content
            if isCoverPage {
                // Draw cover image directly from pre-extracted data
                let coverData = isFrontCoverPage ? frontCoverImageData : backCoverImageData
                if let data = coverData, let image = UIImage(data: data) {
                    let imageSize = image.size
                    let widthRatio = paperRect.width / imageSize.width
                    let heightRatio = paperRect.height / imageSize.height
                    let scale = min(widthRatio, heightRatio)
                    let scaledWidth = imageSize.width * scale
                    let scaledHeight = imageSize.height * scale
                    let drawX = (paperRect.width - scaledWidth) / 2
                    let drawY = (paperRect.height - scaledHeight) / 2
                    let imageRect = CGRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight)
                    cgContext.saveGState()
                    image.draw(in: imageRect)
                    cgContext.restoreGState()
                }
            } else if slice.characterRange.length > 0 {
                let pageText = slice.attributedString.attributedSubstring(from: slice.characterRange)
                
                // Vertically center epigraph/dedication pages
                let shouldCenter = verticallyCenteredChunkIndices.contains(slice.chunkIndex)
                
                let drawRect: CGRect
                if shouldCenter {
                    // Calculate actual text height to vertically center content
                    let measureRect = CGRect(
                        x: pageSetup.marginLeft,
                        y: 0,
                        width: contentRect.width,
                        height: CGFloat.greatestFiniteMagnitude
                    )
                    let boundingRect = pageText.boundingRect(
                        with: measureRect.size,
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    let textHeight = ceil(boundingRect.height)
                    let yOffset = pageSetup.marginTop + (contentRect.height - textHeight) / 2
                    drawRect = CGRect(
                        x: pageSetup.marginLeft,
                        y: max(pageSetup.marginTop, yOffset),
                        width: contentRect.width,
                        height: contentRect.height
                    )
                } else {
                    drawRect = CGRect(
                        x: pageSetup.marginLeft,
                        y: pageSetup.marginTop,
                        width: contentRect.width,
                        height: contentRect.height
                    )
                }
                
                cgContext.saveGState()
                cgContext.clip(to: drawRect)
                pageText.draw(in: drawRect)
                
                // Draw paragraph numbers for numbered styles
                if let styleSheet = project.styleSheet {
                    Self.drawParagraphNumbers(
                        in: pageText,
                        drawRect: drawRect,
                        styleSheet: styleSheet,
                        styleCounters: &fastPathStyleCounters,
                        lastNumberForStyle: &fastPathLastNumberForStyle
                    )
                }
                
                cgContext.restoreGState()
            }
            
            // Report progress every 5 pages
            let done = pageIndex + 1
            if done % 5 == 0 || done == totalPages {
                progress(done, totalPages)
            }
        }
        
        UIGraphicsEndPDFContext()
        
        #if DEBUG
        print("✅ [PrintService] Fast-path PDF created: \(totalPages) pages")
        #endif
        return pdfData as Data
    }

    private static func containsImageAttachments(in content: NSAttributedString) -> Bool {
        var hasImageAttachment = false
        content.enumerateAttribute(.attachment, in: NSRange(location: 0, length: content.length), options: []) { value, _, stop in
            if value is ImageAttachment {
                hasImageAttachment = true
                stop.pointee = true
            }
        }
        return hasImageAttachment
    }
    
    /// Prepare an attributed string for PDF rendering (shared between fast and standard paths)
    private static func prepareAttributedStringForPDF(_ mutable: NSMutableAttributedString) {
        // Replace footnote markers with superscript numbers, remove comments
        var replacements: [(range: NSRange, replacement: NSAttributedString)] = []
        mutable.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            if let footnoteAttachment = attachment as? FootnoteAttachment {
                let numberString = "\(footnoteAttachment.number)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.systemBlue,
                    .baselineOffset: 2
                ]
                replacements.append((range: range, replacement: NSAttributedString(string: numberString, attributes: attributes)))
            } else if attachment is CommentAttachment {
                replacements.append((range: range, replacement: NSAttributedString(string: "")))
            }
        }
        for (range, replacement) in replacements.reversed() {
            mutable.replaceCharacters(in: range, with: replacement)
        }

        // Marked poem sections are an editor-only visual hint.
        // Keep the semantic marker, but remove gray foreground/background for output.
        mutable.enumerateAttribute(.poemSectionType, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let raw = value as? String,
                  let sectionType = PoemSectionType(rawValue: raw),
                  !sectionType.isAnalyzed else {
                return
            }
            mutable.removeAttribute(.foregroundColor, range: range)
            mutable.removeAttribute(.backgroundColor, range: range)
        }
        
        // Remove background colors (editing-only tints)
        mutable.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutable.length))
        
        // Convert dynamic colors to fixed light-mode colors
        mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            if let color = value as? UIColor {
                let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                if resolved != color {
                    mutable.addAttribute(.foregroundColor, value: resolved, range: range)
                }
            }
        }
        // Ensure all text has explicit foreground color
        mutable.enumerateAttributes(in: NSRange(location: 0, length: mutable.length), options: []) { attributes, range, _ in
            if attributes[.foregroundColor] == nil {
                mutable.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            }
        }
    }
    
    /// Convert an integer to a lowercase roman numeral string
    private static func toRomanNumeral(_ number: Int) -> String {
        guard number > 0 else { return "" }
        let values = [(1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
                      (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
                      (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var result = ""
        var remaining = number
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
    
    /// Draw paragraph numbers for numbered styles in a PDF context.
    /// Mutates running counter state so numbers increment correctly across pages.
    static func drawParagraphNumbers(
        in attributedString: NSAttributedString,
        drawRect: CGRect,
        styleSheet: StyleSheet,
        styleCounters: inout [String: Int],
        lastNumberForStyle: inout [String: Int]
    ) {
        // Build parent map
        var parentMap: [String: String] = [:]
        if let styles = styleSheet.textStyles {
            for style in styles {
                if let parentName = style.parentStyleName, !parentName.isEmpty {
                    parentMap[style.name] = parentName
                }
            }
        }
        
        // Use a temporary TextKit stack to compute line positions
        let tempStorage = NSTextStorage(attributedString: attributedString)
        let tempLM = NSLayoutManager()
        let tempContainer = NSTextContainer(size: CGSize(width: drawRect.width, height: drawRect.height))
        tempContainer.lineFragmentPadding = 0
        tempStorage.addLayoutManager(tempLM)
        tempLM.addTextContainer(tempContainer)
        tempLM.ensureLayout(for: tempContainer)
        
        let text = attributedString.string as NSString
        let length = attributedString.length
        var scanLocation = 0
        
        while scanLocation < length {
            let paragraphRange = text.paragraphRange(for: NSRange(location: scanLocation, length: 0))
            defer { scanLocation = NSMaxRange(paragraphRange) }
            
            guard paragraphRange.location < length else { continue }
            let attrLocation = NumberingLayoutManager.firstContentCharacterLocation(
                in: paragraphRange,
                text: text
            )
            guard attrLocation >= 0 else { continue }
            
            let attrs = tempStorage.attributes(at: attrLocation, effectiveRange: nil)
            let styleName = attrs[.textStyle] as? String
            let style = styleName.flatMap { styleSheet.style(named: $0) }
            
            guard let styleName = styleName,
                  let style = style,
                  style.numberFormat != .none else { continue }
            
            // Handle parent reset
            if let parentName = parentMap[styleName] {
                let currentParentNumber = lastNumberForStyle[parentName] ?? 0
                let trackedParentNumber = lastNumberForStyle["\(styleName)_parentNum"] ?? 0
                if currentParentNumber != trackedParentNumber {
                    styleCounters[styleName] = 0
                    lastNumberForStyle["\(styleName)_parentNum"] = currentParentNumber
                }
            }
            
            let counter = (styleCounters[styleName] ?? 0) + 1
            styleCounters[styleName] = counter
            lastNumberForStyle[styleName] = counter
            
            // Build formatted number
            let formattedNumber: String
            var hasParent = false
            var cur: String? = styleName
            while let name = cur, parentMap[name] != nil {
                hasParent = true
                cur = parentMap[name]
            }
            
            if hasParent {
                var segments: [(styleName: String, number: Int)] = []
                var walk: String? = styleName
                while let name = walk {
                    let num = (name == styleName) ? counter : (lastNumberForStyle[name] ?? 0)
                    segments.append((name, num))
                    walk = parentMap[name]
                }
                segments.reverse()
                let parts: [String] = segments.map { seg in
                    let level = seg.styleName.contains("level-3") ? 2 : (seg.styleName.contains("level-2") ? 1 : 0)
                    if let s = styleSheet.style(named: seg.styleName), s.numberFormat != .none {
                        return s.numberFormat.symbol(for: max(seg.number - 1, 0), adornment: .plain, level: level)
                    }
                    return "\(seg.number)"
                }
                let combined = parts.joined(separator: ".")
                formattedNumber = style.numberAdornment.apply(to: combined)
            } else {
                let level = styleName.contains("level-3") ? 2 : (styleName.contains("level-2") ? 1 : 0)
                formattedNumber = style.numberFormat.symbol(for: counter - 1, adornment: style.numberAdornment, level: level)
            }
            
            // Get line position from temp layout manager
            let contentRange = NSRange(
                location: attrLocation,
                length: max(NSMaxRange(paragraphRange) - attrLocation, 0)
            )
            let glyphRange = tempLM.glyphRange(forCharacterRange: contentRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }
            let lineFragmentRect = tempLM.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let glyphLocation = tempLM.location(forGlyphAt: glyphRange.location)
            
            let paragraphFont = attrs[.font] as? UIFont ?? style.generateFont(applyPlatformScaling: false)
            let paragraphColor = (attrs[.foregroundColor] as? UIColor)?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)) ?? UIColor.black
            
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: paragraphFont,
                .foregroundColor: paragraphColor
            ]
            let numberString = formattedNumber as NSString
            let numberSize = numberString.size(withAttributes: numberAttributes)
            
            let numberX: CGFloat
            if style.styleCategory == .list {
                let gap: CGFloat = 4.0
                numberX = drawRect.origin.x + style.headIndent - numberSize.width - gap
            } else {
                // Non-list numbered paragraphs (headings): draw at the style's base firstLineIndent
                // Text starts at firstLineIndent + numberWidth; number sits flush left at margin
                numberX = drawRect.origin.x + style.firstLineIndent
            }
            
            let numberY = NumberingLayoutManager.numberDrawingY(
                originY: drawRect.origin.y,
                lineFragmentMinY: lineFragmentRect.minY,
                glyphBaselineOffset: glyphLocation.y,
                font: paragraphFont
            )
            
            let numberRect = CGRect(x: numberX, y: numberY, width: numberSize.width, height: numberSize.height)
            numberString.draw(in: numberRect, withAttributes: numberAttributes)
        }
    }
    
    /// Draw header or footer text for the fast-path renderer
    private static func drawHeaderFooter(
        left: String?,
        center: String?,
        right: String?,
        rect: CGRect,
        pageNumberString: String,
        totalPages: Int,
        project: Project,
        version: Version? = nil,
        fileCollectionMap: [(offset: Int, collectionName: String)] = [],
        pageCharOffset: Int = 0,
        context: CGContext
    ) {
        let baseFont = UIFont.systemFont(ofSize: 12)
        let textColor = UIColor.darkGray
        
        let labelHeight: CGFloat = min(rect.height, 20)
        let verticalCenter = rect.origin.y + (rect.height - labelHeight) / 2
        
        func resolve(_ text: String?) -> String {
            guard var result = text, !result.isEmpty else { return "" }
            if result.contains("{{Date}}") {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                result = result.replacingOccurrences(of: "{{Date}}", with: formatter.string(from: Date()))
            }
            if result.contains("{{Page Number}}") {
                result = result.replacingOccurrences(of: "{{Page Number}}", with: pageNumberString)
            }
            if result.contains("{{Folder}}") {
                let folderName: String
                switch project.type {
                case .poetry:
                    folderName = NSLocalizedString("folder.poems", comment: "Poems")
                case .fiction:
                    folderName = NSLocalizedString("folder.scenes", comment: "Scenes")
                case .drama:
                    folderName = NSLocalizedString("folder.scripts", comment: "Scripts")
                default:
                    folderName = NSLocalizedString("folder.sections", comment: "Sections")
                }
                result = result.replacingOccurrences(of: "{{Folder}}", with: folderName)
            }
            if result.contains("{{Collection}}") {
                let collectionName: String
                if let textFile = version?.textFile {
                    collectionName = textFile.poetryCollections?.first?.name
                        ?? textFile.sections?.first?.name
                        ?? ""
                } else if !fileCollectionMap.isEmpty {
                    // Manuscript mode: look up collection by page character offset
                    var found = ""
                    for entry in fileCollectionMap {
                        if entry.offset <= pageCharOffset {
                            found = entry.collectionName
                        } else {
                            break
                        }
                    }
                    collectionName = found
                } else {
                    collectionName = ""
                }
                result = result.replacingOccurrences(of: "{{Collection}}", with: collectionName)
            }
            if result.contains("{{Project Name}}") {
                result = result.replacingOccurrences(of: "{{Project Name}}", with: project.name ?? "")
            }
            if result.contains("{{Author}}") {
                result = result.replacingOccurrences(of: "{{Author}}", with: project.author ?? "")
            }
            return result
        }
        
        let leftText = resolve(left)
        let centerText = resolve(center)
        let rightText = resolve(right)
        let headerItems: [(text: String, alignment: NSTextAlignment, rect: CGRect)]
        let populatedCount = [leftText, centerText, rightText].filter { !$0.isEmpty }.count
        if populatedCount == 1 {
            let text = !leftText.isEmpty ? leftText : (!centerText.isEmpty ? centerText : rightText)
            let alignment: NSTextAlignment = !leftText.isEmpty ? .left : (!centerText.isEmpty ? .center : .right)
            headerItems = [(text, alignment, CGRect(x: rect.origin.x, y: verticalCenter, width: rect.width, height: labelHeight))]
        } else {
            headerItems = [
                (leftText, .left, CGRect(x: rect.origin.x, y: verticalCenter, width: rect.width / 3, height: labelHeight)),
                (centerText, .center, CGRect(x: rect.origin.x + rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight)),
                (rightText, .right, CGRect(x: rect.origin.x + 2 * rect.width / 3, y: verticalCenter, width: rect.width / 3, height: labelHeight))
            ]
        }

        for item in headerItems where !item.text.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = item.alignment
            let font = fittingHeaderFooterFont(for: item.text, baseFont: baseFont, maxWidth: item.rect.width)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
            item.text.draw(in: item.rect, withAttributes: attributes)
        }
    }

    private static func fittingHeaderFooterFont(for text: String, baseFont: UIFont, maxWidth: CGFloat) -> UIFont {
        guard !text.isEmpty, maxWidth > 0 else { return baseFont }
        var fontSize = baseFont.pointSize
        while fontSize > 7 {
            let font = baseFont.withSize(fontSize)
            let width = (text as NSString).size(withAttributes: [.font: font]).width
            if width <= maxWidth { return font }
            fontSize -= 0.5
        }
        return baseFont.withSize(7)
    }
    
    // MARK: - Font Scaling Helper
    
    /// Remove platform-specific font scaling to get actual print size
    /// Database contains Mac-rendered fonts (22.1pt), both platforms need to scale down for print
    private static func removePlatformScaling(from attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if let font = value as? UIFont {
                // Reverse the Catalyst scaling from Mac's generateFont()
                // Database: 22.1pt → Print: 17pt (÷kCatalystFontScale)
                let printSize = font.pointSize / kCatalystFontScale
                let printFont = font.withSize(printSize)
                mutable.addAttribute(.font, value: printFont, range: range)
            }
        }
        
        // Also scale paragraph indents to match the descaled fonts
        let scaleFactor: CGFloat = 1.0 / kCatalystFontScale
        mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            guard let ps = value as? NSParagraphStyle else { return }
            let needsScale = ps.firstLineHeadIndent != 0 || ps.headIndent != 0 || ps.tailIndent != 0
            guard needsScale else { return }
            let mps = ps.mutableCopy() as! NSMutableParagraphStyle
            if mps.firstLineHeadIndent != 0 { mps.firstLineHeadIndent *= scaleFactor }
            if mps.headIndent != 0 { mps.headIndent *= scaleFactor }
            if mps.tailIndent != 0 { mps.tailIndent *= scaleFactor }
            mutable.addAttribute(.paragraphStyle, value: mps, range: range)
        }
        
        return mutable
    }
    
    // MARK: - Utility Methods
    
    /// Check if printing is available on this device
    /// - Returns: True if printing is supported
    static func isPrintingAvailable() -> Bool {
        #if targetEnvironment(macCatalyst)
        // Mac Catalyst supports system print workflows even when UIKit's
        // iOS-centric availability probe can report false.
        return true
        #else
        return UIPrintInteractionController.isPrintingAvailable
        #endif
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
