//
//  ManuscriptPreviewView.swift
//  Writing Shed Pro
//
//  In-app PDF preview for assembled manuscripts.
//  Displays a rendered PDF using PDFKit.
//  Supports async generation — shows a progress indicator while the PDF is being built.
//

import SwiftUI
import PDFKit

/// In-app PDF viewer for manuscript preview.
/// Pass `pdfData` for immediate display, or `pdfGenerator` for async background generation.
struct ManuscriptPreviewView: View {
    /// Pre-generated PDF data (shown immediately)
    let pdfData: Data?
    let title: String
    /// Optional async generator — called when pdfData is nil to build the PDF in the background.
    /// The closure receives a progress callback: (fraction 0–1, display text).
    var pdfGenerator: ((@escaping (Double, String) -> Void) async -> Data?)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var generatedData: Data?
    @State private var isGenerating = false
    @State private var generationFailed = false
    @State private var progressFraction: Double = 0
    @State private var progressText: String = ""
    
    /// The data to display — either pre-supplied or async-generated
    private var displayData: Data? {
        pdfData ?? generatedData
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let data = displayData {
                    PDFKitView(data: data)
                        .ignoresSafeArea(edges: .bottom)
                } else if generationFailed {
                    ContentUnavailableView {
                        Label(NSLocalizedString("manuscript.error.exportFailedGeneric", comment: "Failed"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(NSLocalizedString("manuscript.preview.generationFailed", comment: "Could not generate the manuscript preview."))
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView(value: progressFraction)
                            .frame(width: 200)
                            .animation(.linear(duration: 0.3), value: progressFraction)
                        Text(progressText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            guard pdfData == nil, let generator = pdfGenerator else { return }
            isGenerating = true
            progressText = NSLocalizedString("manuscript.preview.generating", comment: "Generating preview…")
            let data = await generator { fraction, text in
                DispatchQueue.main.async {
                    self.progressFraction = fraction
                    self.progressText = text
                }
            }
            isGenerating = false
            if let data {
                generatedData = data
            } else {
                generationFailed = true
            }
        }
    }
}

// MARK: - PDFKit UIViewRepresentable

/// Wraps PDFKit's PDFView for use in SwiftUI
struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}
