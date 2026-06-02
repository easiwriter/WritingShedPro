//
//  DMLTextEditor.swift
//  Writing Shed Pro
//
//  A simple UITextView wrapper for DML editing that tracks cursor position
//

import SwiftUI
import UIKit

/// A text editor for DML source that tracks cursor position and shows line numbers.
struct DMLTextEditor: UIViewRepresentable {
    let project: Project
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var onUndoManagerReady: ((UndoManager?) -> Void)?
    var onTextViewReady: ((UITextView) -> Void)?
    
    private let lineNumberGutterWidth: CGFloat = 56
    
    func makeUIView(context: Context) -> UITextView {
        let textStorage = NSTextStorage()
        let layoutManager = NumberingLayoutManager()
        let textContainer = NSTextContainer(size: .zero)

        layoutManager.project = project
        layoutManager.showDocumentLineNumbers = true

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = UIFont(name: "Courier", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8 + lineNumberGutterWidth, bottom: 8, right: 8)
        textView.text = text
        textView.selectedRange = selectedRange
        textView.layoutManager.allowsNonContiguousLayout = false
        
        // Store reference in coordinator
        context.coordinator.textView = textView
        
        // Notify about undo manager and text view
        DispatchQueue.main.async {
            onUndoManagerReady?(textView.undoManager)
            onTextViewReady?(textView)
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update text if it changed externally
        if uiView.text != text {
            // Preserve cursor position when possible
            let previousRange = uiView.selectedRange
            uiView.text = text
            
            // Restore cursor position if within bounds
            if previousRange.location <= text.count {
                uiView.selectedRange = previousRange
            }
            uiView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: max(1, text.count)))
            uiView.setNeedsDisplay()
        }

        if let layoutManager = uiView.layoutManager as? NumberingLayoutManager,
           layoutManager.showDocumentLineNumbers != true {
            layoutManager.showDocumentLineNumbers = true
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: uiView.textStorage.length))
        }
        
        // Update selection if it changed externally (e.g., after insertion)
        if uiView.selectedRange != selectedRange && selectedRange.location <= text.count {
            uiView.selectedRange = selectedRange
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: DMLTextEditor
        weak var textView: UITextView?
        
        init(_ parent: DMLTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // Defer state update to avoid modifying state during view update
            DispatchQueue.main.async {
                self.parent.selectedRange = textView.selectedRange
            }
        }
        
        // MARK: - Undo/Redo Support
        
        func performUndo() {
            textView?.undoManager?.undo()
        }
        
        func performRedo() {
            textView?.undoManager?.redo()
        }
        
        var canUndo: Bool {
            textView?.undoManager?.canUndo ?? false
        }
        
        var canRedo: Bool {
            textView?.undoManager?.canRedo ?? false
        }
    }
}
