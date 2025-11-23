//
//  ImageStyleSheetEditorView.swift
//  Writing Shed Pro
//
//  Editor for ImageStyle in stylesheet (not individual image instances)
//

import SwiftUI
import SwiftData

struct ImageStyleSheetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var imageStyle: ImageStyle
    
    @State private var scaleText: String = ""
    
    var body: some View {
        Form {
            // Name Section
            Section("imageStyleEditor.styleName") {
                if imageStyle.isSystemStyle {
                    HStack {
                        Text("imageStyleEditor.displayName")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(imageStyle.displayName)
                    }
                    
                    Text("imageStyleEditor.systemStyle.warning")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("imageStyleEditor.displayName", text: $imageStyle.displayName)
                        .accessibilityLabel("imageStyleEditor.displayName.accessibility")
                }
            }
            
            // Default Scale Section
            Section {
                HStack {
                    Text("imageStyleEditor.scale")
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    Button(action: {
                        decrementScale()
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                    }
                    .disabled(imageStyle.defaultScale <= 0.1)
                    .buttonStyle(.plain)
                    .accessibilityLabel("imageStyleEditor.decreaseScale.accessibility")
                    
                    TextField("100", text: $scaleText, onEditingChanged: { isEditing in
                        if !isEditing {
                            // When user finishes editing, validate and update
                            updateScaleFromText(scaleText)
                        }
                    })
                    .font(.headline)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("imageStyleEditor.scaleValue.accessibility")
                    
                    Text("%")
                        .font(.headline)
                    
                    Button(action: {
                        incrementScale()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                    }
                    .disabled(imageStyle.defaultScale >= 2.0)
                    .buttonStyle(.plain)
                    .accessibilityLabel("imageStyleEditor.increaseScale.accessibility")
                }
            } header: {
                Text("imageStyleEditor.size")
            } footer: {
                Text("imageStyleEditor.size.footer")
                    .font(.caption)
            }
            
            // Default Alignment Section
            Section {
                HStack(spacing: 20) {
                    Spacer()
                    
                    AlignmentButton(
                        icon: "text.alignleft",
                        isSelected: imageStyle.defaultAlignment == .left,
                        action: { imageStyle.defaultAlignment = .left }
                    )
                    
                    AlignmentButton(
                        icon: "text.aligncenter",
                        isSelected: imageStyle.defaultAlignment == .center,
                        action: { imageStyle.defaultAlignment = .center }
                    )
                    
                    AlignmentButton(
                        icon: "text.alignright",
                        isSelected: imageStyle.defaultAlignment == .right,
                        action: { imageStyle.defaultAlignment = .right }
                    )
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("imageStyleEditor.alignment.accessibility")
            } header: {
                Text("imageStyleEditor.alignment")
            } footer: {
                Text("imageStyleEditor.alignment.footer")
                    .font(.caption)
            }
            
            // Caption Section
            Section {
                Toggle("imageStyleEditor.captionByDefault", isOn: $imageStyle.hasCaptionByDefault)
                    .accessibilityLabel("imageStyleEditor.captionByDefault.accessibility")
                
                if imageStyle.hasCaptionByDefault {
                    HStack {
                        Text("imageStyleEditor.captionStyle")
                        Spacer()
                        Text(imageStyle.defaultCaptionStyle)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("imageStyleEditor.caption")
            } footer: {
                if imageStyle.hasCaptionByDefault {
                    Text(String(format: NSLocalizedString("imageStyleEditor.caption.footer.enabled", comment: ""), imageStyle.defaultCaptionStyle))
                        .font(.caption)
                } else {
                    Text("imageStyleEditor.caption.footer.disabled")
                        .font(.caption)
                }
            }
        }
        .navigationTitle(imageStyle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("button.done") {
                    saveChanges()
                    dismiss()
                }
            }
        }
        .onAppear {
            scaleText = "\(Int(imageStyle.defaultScale * 100))"
        }
    }
    
    // MARK: - Scale Management
    
    private func incrementScale() {
        let newScale = min(imageStyle.defaultScale + 0.1, 2.0)
        imageStyle.defaultScale = newScale
        scaleText = "\(Int(newScale * 100))"
    }
    
    private func decrementScale() {
        let newScale = max(imageStyle.defaultScale - 0.1, 0.1)
        imageStyle.defaultScale = newScale
        scaleText = "\(Int(newScale * 100))"
    }
    
    private func updateScaleFromText(_ text: String) {
        // Parse percentage from text
        let cleanText = text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        
        guard let percentage = Int(cleanText) else {
            // Invalid input - revert to current scale
            scaleText = "\(Int(imageStyle.defaultScale * 100))"
            return
        }
        
        // Clamp to valid range (10% to 200%)
        let clampedPercentage = max(10, min(200, percentage))
        imageStyle.defaultScale = CGFloat(clampedPercentage) / 100.0
        
        // Update text field to show clamped value
        if clampedPercentage != percentage {
            scaleText = "\(clampedPercentage)"
        }
    }
    
    private func saveChanges() {
        imageStyle.modifiedDate = Date()
        
        do {
            try modelContext.save()
            print("✅ Saved image style: \(imageStyle.displayName)")
        } catch {
            print("❌ Error saving image style: \(error)")
        }
    }
}
