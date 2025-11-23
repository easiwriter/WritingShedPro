//
//  FontPickerView.swift
//  Writing Shed Pro
//
//  Comprehensive font picker with family and variant selection
//

import SwiftUI
import UIKit

struct FontPickerView: View {
    @Binding var selectedFontFamily: String?
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingVariantPicker = false
    @State private var selectedFamily: String?
    @State private var availableVariants: [String] = []
    
    // Get all available font families
    private var fontFamilies: [String] {
        UIFont.familyNames.sorted()
    }
    
    private var filteredFamilies: [String] {
        if searchText.isEmpty {
            return fontFamilies
        }
        return fontFamilies.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredFamilies, id: \.self) { family in
                    Button(action: {
                        selectedFamily = family
                        availableVariants = UIFont.fontNames(forFamilyName: family).sorted()
                        if availableVariants.count > 1 {
                            showingVariantPicker = true
                        } else {
                            // Only one variant, select it directly
                            selectedFontFamily = family
                            dismiss()
                        }
                    }) {
                        HStack {
                            // Font name in its own typeface
                            Text(family)
                                .font(Font(UIFont(name: UIFont.fontNames(forFamilyName: family).first ?? family, size: 17) ?? UIFont.systemFont(ofSize: 17)))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Checkmark if selected
                            if selectedFontFamily == family {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                            
                            // Show more button if multiple variants
                            if UIFont.fontNames(forFamilyName: family).count > 1 {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search fonts")
            .navigationTitle(NSLocalizedString("fontPicker.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingVariantPicker) {
                if let family = selectedFamily {
                    FontVariantPickerView(
                        fontFamily: family,
                        variants: availableVariants,
                        selectedFontFamily: $selectedFontFamily
                    )
                }
            }
        }
    }
}

// MARK: - Font Variant Picker

struct FontVariantPickerView: View {
    let fontFamily: String
    let variants: [String]
    @Binding var selectedFontFamily: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(variants, id: \.self) { variant in
                    Button(action: {
                        selectedFontFamily = fontFamily
                        dismiss()
                    }) {
                        HStack {
                            // Variant name (extract style from full name)
                            Text(variantDisplayName(variant))
                                .font(Font(UIFont(name: variant, size: 17) ?? UIFont.systemFont(ofSize: 17)))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Checkmark if this is current
                            if selectedFontFamily == fontFamily {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(fontFamily)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func variantDisplayName(_ fullName: String) -> String {
        // Extract variant name (e.g., "Helvetica-Bold" -> "Bold")
        let components = fullName.components(separatedBy: "-")
        if components.count > 1 {
            return components.dropFirst().joined(separator: "-")
        }
        return "Regular"
    }
}

// MARK: - Preview

#Preview {
    FontPickerView(selectedFontFamily: .constant("Helvetica Neue"))
}
