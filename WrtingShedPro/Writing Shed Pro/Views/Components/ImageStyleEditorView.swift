import SwiftUI
import UIKit

/// SwiftUI view for editing image properties (scale, alignment, caption)
/// Presented as a sheet when inserting or editing images
struct ImageStyleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isScaleFieldFocused: Bool
    @State private var showInvalidScaleAlert = false
    
    // Image data and properties
    let imageData: Data?
    @State private var scale: CGFloat
    @State private var scaleText: String
    @State private var alignment: ImageAttachment.ImageAlignment
    @State private var hasCaption: Bool
    @State private var captionText: String
    @State private var captionStyle: String
    
    // Available caption styles from stylesheet
    let availableCaptionStyles: [String]
    
    // Callback when user applies changes
    let onApply: (Data?, CGFloat, ImageAttachment.ImageAlignment, Bool, String, String) -> Void
    
    init(
        imageData: Data? = nil,
        scale: CGFloat = 1.0,
        alignment: ImageAttachment.ImageAlignment = .center,
        hasCaption: Bool = false,
        captionText: String = "",
        captionStyle: String = "body",
        availableCaptionStyles: [String] = ["body", "caption1", "caption2", "footnote"],
        onApply: @escaping (Data?, CGFloat, ImageAttachment.ImageAlignment, Bool, String, String) -> Void
    ) {
        print("🎨 ImageStyleEditorView.init called with imageData: \(imageData?.count ?? 0) bytes")
        self.imageData = imageData
        self._scale = State(initialValue: scale)
        self._scaleText = State(initialValue: "\(Int(scale * 100))")
        self._alignment = State(initialValue: alignment)
        self._hasCaption = State(initialValue: hasCaption)
        self._captionText = State(initialValue: captionText)
        self._captionStyle = State(initialValue: captionStyle)
        self.availableCaptionStyles = availableCaptionStyles
        self.onApply = onApply
    }
    
    var body: some View {
        let _ = print("🎨 ImageStyleEditorView.body rendering, imageData: \(imageData?.count ?? 0) bytes")
        
        NavigationStack {
            Form {
                // Image Preview Section
                if let imageData = imageData,
                   let uiImage = UIImage(data: imageData) {
                    Section("Preview") {
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                            Spacer()
                        }
                    }
                } else {
                    Section("Preview") {
                        Text("No image data")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Scale Section
                Section {
                    HStack {
                        Text("Scale")
                            .frame(width: 80, alignment: .leading)
                        
                        Spacer()
                        
                        Button(action: {
                            decrementScale()
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                        }
                        .disabled(scale <= 0.1)
                        .buttonStyle(.plain)
                        
                        TextField("100", text: $scaleText)
                            .font(.headline)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .focused($isScaleFieldFocused)
                            .onSubmit {
                                commitScaleFromText()
                            }
                            .onChange(of: isScaleFieldFocused) { oldValue, newValue in
                                // When field loses focus, commit the value
                                if !newValue {
                                    commitScaleFromText()
                                }
                            }
                        
                        Text("%")
                            .font(.headline)
                        
                        Button(action: {
                            incrementScale()
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                        }
                        .disabled(scale >= 2.0)
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Size")
                }
                
                // Alignment Section
                Section {
                    HStack(spacing: 20) {
                        Spacer()
                        
                        AlignmentButton(
                            icon: "text.alignleft",
                            isSelected: alignment == .left,
                            action: { alignment = .left }
                        )
                        
                        AlignmentButton(
                            icon: "text.aligncenter",
                            isSelected: alignment == .center,
                            action: { alignment = .center }
                        )
                        
                        AlignmentButton(
                            icon: "text.alignright",
                            isSelected: alignment == .right,
                            action: { alignment = .right }
                        )
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Alignment")
                }
                
                // Caption Section
                Section {
                    Toggle("Show Caption", isOn: $hasCaption)
                    
                    if hasCaption {
                        TextField("Caption text", text: $captionText)
                        
                        Picker("Caption Style", selection: $captionStyle) {
                            ForEach(availableCaptionStyles, id: \.self) { style in
                                Text(style.capitalized)
                                    .tag(style)
                            }
                        }
                    }
                } header: {
                    Text("Caption")
                }
            }
            .navigationTitle("Image Properties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply(imageData, scale, alignment, hasCaption, captionText, captionStyle)
                        dismiss()
                    }
                    .disabled(imageData == nil)
                }
            }
        }
        .alert("Invalid Scale", isPresented: $showInvalidScaleAlert) {
            Button("OK", role: .cancel) {
                // Reset to current scale
                scaleText = "\(Int(scale * 100))"
            }
        } message: {
            Text("Please enter a number between 10 and 200")
        }
    }
    
    // MARK: - Helper Methods
    
    private func incrementScale() {
        let newScale = min(scale + 0.05, 2.0)
        scale = (newScale * 100).rounded() / 100 // Round to 2 decimal places
        scaleText = "\(Int(scale * 100))"
        isScaleFieldFocused = false // Dismiss keyboard
    }
    
    private func decrementScale() {
        let newScale = max(scale - 0.05, 0.1)
        scale = (newScale * 100).rounded() / 100 // Round to 2 decimal places
        scaleText = "\(Int(scale * 100))"
        isScaleFieldFocused = false // Dismiss keyboard
    }
    
    private func commitScaleFromText() {
        // Trim whitespace
        let trimmed = scaleText.trimmingCharacters(in: .whitespaces)
        
        // Empty string is invalid - show alert
        if trimmed.isEmpty {
            showInvalidScaleAlert = true
            return
        }
        
        // Try to parse as integer
        if let percentage = Int(trimmed) {
            // Check if in valid range (10-200%)
            if percentage >= 10 && percentage <= 200 {
                scale = CGFloat(percentage) / 100.0
                scaleText = "\(percentage)"
            } else {
                // Out of range - show alert
                showInvalidScaleAlert = true
            }
        } else {
            // Not a valid number - show alert
            showInvalidScaleAlert = true
        }
    }
}

// MARK: - Alignment Button Component

struct AlignmentButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct ImageStyleEditorView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a simple test image
        let testImage = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let testData = testImage.pngData()
        
        ImageStyleEditorView(
            imageData: testData,
            scale: 1.0,
            alignment: .center,
            hasCaption: true,
            captionText: "Test Caption",
            captionStyle: "caption1",
            onApply: { _, _, _, _, _, _ in }
        )
    }
}
