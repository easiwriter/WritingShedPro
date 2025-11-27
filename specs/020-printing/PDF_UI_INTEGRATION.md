# Adding PDF Export to UI - Quick Implementation Guide

## FileEditView - Add PDF Export Button

### Option 1: Add to Toolbar (Next to Print Button)

```swift
// In FileEditView toolbar
.toolbar {
    // ... existing buttons ...
    
    // PDF Export button
    ToolbarItem(placement: .primaryAction) {
        Button(action: exportPDF) {
            Label("Export PDF", systemImage: "doc.fill")
        }
        .disabled(textFile == nil)
    }
}

// Add method
private func exportPDF() {
    guard let file = textFile else { return }
    
    if let pdfData = PrintService.generatePDF(from: file) {
        PrintService.sharePDF(pdfData, filename: file.name, from: viewController)
    } else {
        pdfErrorMessage = "Failed to generate PDF"
        showPDFError = true
    }
}

// Add state
@State private var showPDFError = false
@State private var pdfErrorMessage = ""

// Add alert
.alert("PDF Error", isPresented: $showPDFError) {
    Button("OK", role: .cancel) { }
} message: {
    Text(pdfErrorMessage)
}
```

### Option 2: Add Menu with Print and PDF Options

```swift
// Replace single print button with menu
ToolbarItem(placement: .primaryAction) {
    Menu {
        Button(action: printFile) {
            Label("Print", systemImage: "printer")
        }
        
        Button(action: exportPDF) {
            Label("Export PDF", systemImage: "doc.fill")
        }
        
        Button(action: savePDF) {
            Label("Save PDF", systemImage: "square.and.arrow.down")
        }
    } label: {
        Label("Export Options", systemImage: "ellipsis.circle")
    }
    .disabled(textFile == nil)
}

private func savePDF() {
    guard let file = textFile else { return }
    
    if let pdfData = PrintService.generatePDF(from: file),
       let url = PrintService.savePDF(pdfData, filename: file.name) {
        pdfSuccessMessage = "PDF saved to Documents"
        showPDFSuccess = true
    } else {
        pdfErrorMessage = "Failed to save PDF"
        showPDFError = true
    }
}
```

## PaginatedDocumentView - Add PDF Export

```swift
// In zoom controls HStack (next to print button)
HStack {
    // ... existing zoom buttons ...
    
    // Print button
    Button(action: printDocument) {
        Image(systemName: "printer")
    }
    
    // PDF export button
    Button(action: exportPDF) {
        Image(systemName: "doc.fill")
    }
    .help("Export as PDF")
}

private func exportPDF() {
    guard let file = file else { return }
    
    if let pdfData = PrintService.generatePDF(from: file) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            PrintService.sharePDF(pdfData, filename: file.name, from: rootViewController)
        }
    }
}
```

## CollectionsView - Export Collection as PDF

```swift
// In collection row swipe actions or context menu
.contextMenu {
    Button(action: { exportCollectionPDF(collection) }) {
        Label("Export as PDF", systemImage: "doc.fill")
    }
    
    // ... other actions ...
}

private func exportCollectionPDF(_ collection: Submission) {
    let files = collection.submittedFiles?.compactMap { $0.textFile } ?? []
    
    guard !files.isEmpty else {
        print("❌ Collection is empty")
        return
    }
    
    if let pdfData = PrintService.generatePDF(
        from: files,
        title: collection.name ?? "Collection"
    ) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            PrintService.sharePDF(
                pdfData,
                filename: collection.name ?? "Collection",
                from: rootViewController
            )
        }
    }
}
```

## SubmissionsView - Export Submission as PDF

```swift
// Similar to collections
.contextMenu {
    Button(action: { exportSubmissionPDF(submission) }) {
        Label("Export as PDF", systemImage: "doc.fill")
    }
}

private func exportSubmissionPDF(_ submission: Submission) {
    let files = submission.submittedFiles?.compactMap { $0.textFile } ?? []
    
    guard !files.isEmpty else { return }
    
    let title = submission.publication?.name ?? submission.name ?? "Submission"
    
    if let pdfData = PrintService.generatePDF(from: files, title: title) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            PrintService.sharePDF(pdfData, filename: title, from: rootViewController)
        }
    }
}
```

## Getting ViewController in SwiftUI

### Option 1: Use UIViewControllerRepresentable

```swift
struct ViewControllerProvider: UIViewControllerRepresentable {
    let callback: (UIViewController) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            callback(vc)
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// Usage in SwiftUI view:
.background(
    ViewControllerProvider { viewController in
        self.viewController = viewController
    }
)

@State private var viewController: UIViewController?
```

### Option 2: Use Window Scene (Simpler)

```swift
private func getViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
        return nil
    }
    return rootViewController
}

// Usage:
if let vc = getViewController() {
    PrintService.sharePDF(pdfData, filename: "Document", from: vc)
}
```

### Option 3: Extension for Easy Access

```swift
extension View {
    func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return windowScene.windows.first?.rootViewController
    }
}

// Usage in any view:
if let vc = getRootViewController() {
    PrintService.sharePDF(pdfData, filename: "Document", from: vc)
}
```

## Complete Example: FileEditView with Print & PDF Menu

```swift
import SwiftUI

struct FileEditView: View {
    @Binding var textFile: TextFile?
    @State private var showExportMenu = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            // ... text editor ...
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Print option
                    Button(action: handlePrint) {
                        Label("Print", systemImage: "printer")
                    }
                    
                    // Export PDF option
                    Button(action: handleExportPDF) {
                        Label("Export PDF", systemImage: "doc.fill")
                    }
                    
                    // Save PDF option
                    Button(action: handleSavePDF) {
                        Label("Save PDF to Documents", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(textFile == nil)
            }
        }
        .alert("Export", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handlePrint() {
        guard let file = textFile,
              let vc = getRootViewController() else { return }
        
        PrintService.printFile(file, from: vc) { success, error in
            if let error = error {
                alertMessage = "Print failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func handleExportPDF() {
        guard let file = textFile,
              let vc = getRootViewController() else { return }
        
        if let pdfData = PrintService.generatePDF(from: file) {
            PrintService.sharePDF(pdfData, filename: file.name, from: vc)
        } else {
            alertMessage = "Failed to generate PDF"
            showAlert = true
        }
    }
    
    private func handleSavePDF() {
        guard let file = textFile else { return }
        
        if let pdfData = PrintService.generatePDF(from: file),
           let url = PrintService.savePDF(pdfData, filename: file.name) {
            alertMessage = "PDF saved to:\n\(url.lastPathComponent)"
            showAlert = true
        } else {
            alertMessage = "Failed to save PDF"
            showAlert = true
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return windowScene.windows.first?.rootViewController
    }
}
```

## Icon Recommendations

- **Print:** `printer` or `printer.fill`
- **Export PDF:** `doc.fill` or `arrow.down.doc.fill`
- **Save PDF:** `square.and.arrow.down` or `square.and.arrow.down.on.square`
- **Share PDF:** `square.and.arrow.up` or `square.and.arrow.up.fill`
- **Menu:** `ellipsis.circle` or `ellipsis.circle.fill`

## User Experience Tips

1. **Show Progress for Large Documents**
   ```swift
   @State private var isGenerating = false
   
   if isGenerating {
       ProgressView("Generating PDF...")
   }
   ```

2. **Confirm Before Large Exports**
   ```swift
   .confirmationDialog("Export PDF?", isPresented: $showConfirm) {
       Button("Export PDF") { exportPDF() }
       Button("Cancel", role: .cancel) { }
   } message: {
       Text("This will create a PDF with \(pageCount) pages.")
   }
   ```

3. **Success Feedback**
   ```swift
   // Use haptic feedback
   let generator = UINotificationFeedbackGenerator()
   generator.notificationOccurred(.success)
   
   // Or show toast
   showToast("PDF exported successfully")
   ```

## Testing Checklist

- [ ] PDF export button appears in toolbar
- [ ] Tapping button generates PDF
- [ ] Share sheet presents correctly
- [ ] PDF opens in Files app
- [ ] PDF preserves formatting
- [ ] Works on iPhone
- [ ] Works on iPad
- [ ] Works on Mac Catalyst
- [ ] Menu dismisses after selection
- [ ] Error handling works
- [ ] Success feedback shown

---

**Next Steps:**
1. Choose a UI approach (toolbar button, menu, or both)
2. Add to FileEditView
3. Add to PaginatedDocumentView
4. Test on device
5. Add to CollectionsView/SubmissionsView (Phase 3)
