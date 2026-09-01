//
//  FontPickerView.swift
//  Writing Shed Pro
//
//  Comprehensive font picker with family and variant selection
//

import SwiftUI
import UIKit

struct FontPickerView: View {
    @Binding var selectedFontFamily: String?  // Font family name (e.g., "Helvetica")
    @Binding var selectedFontName: String?     // Full font name (e.g., "Helvetica-Bold")
    var onFontSelected: (() -> Void)?          // Callback when font changes
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
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
    
    // Helper to check if any variant of this family is selected
    private func isFamilySelected(_ family: String) -> Bool {
        // Check if the selected font name belongs to this family
        let fontName = selectedFontName ?? FontFaceResolver.defaultFontName
        let variants = UIFont.fontNames(forFamilyName: family)
        return variants.contains(fontName)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredFamilies, id: \.self) { family in
                    let variants = UIFont.fontNames(forFamilyName: family).sorted()
                    if variants.count > 1 {
                        Menu {
                            ForEach(variants, id: \.self) { variant in
                                Button {
                                    selectFont(family: family, face: variant)
                                } label: {
                                    if selectedFontName == variant {
                                        Label(variantDisplayName(variant), systemImage: "checkmark")
                                    } else {
                                        Text(variantDisplayName(variant))
                                    }
                                }
                            }
                        } label: {
                            familyRow(family, showsFaceMenu: true)
                        }
                    } else {
                        Button {
                            if let variant = variants.first {
                                selectFont(family: family, face: variant)
                            }
                        } label: {
                            familyRow(family, showsFaceMenu: false)
                        }
                        .buttonStyle(.plain)
                    }
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
        }
    }

    private func selectFont(family: String, face: String) {
        selectedFontFamily = family
        selectedFontName = face
        onFontSelected?()
        dismiss()
    }

    private func familyRow(_ family: String, showsFaceMenu: Bool) -> some View {
        HStack {
            Text(family)
                .font(Font(UIFont(name: UIFont.fontNames(forFamilyName: family).first ?? family, size: 17) ?? UIFont.systemFont(ofSize: 17)))
                .foregroundColor(.primary)
            Spacer()
            if isFamilySelected(family) {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
            if showsFaceMenu {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
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


