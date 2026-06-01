import SwiftUI

/// A sheet view displaying the poetry form reference for a file
/// Shows form name, description, and all structural requirements
struct PoetryFormReference: View {
    let form: PoetryForm
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Form header
                    headerSection
                    
                    // Description
                    descriptionSection
                    
                    // Requirements
                    if hasAnyRequirements {
                        requirementsSection
                    }
                    
                    // Template preview (if available)
                    if !form.templateContent.isEmpty {
                        templateSection
                    }
                }
                .padding()
            }
            .navigationTitle(form.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("poetryFormReference.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(form.category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(categoryColor)
                    .cornerRadius(12)
                
                Spacer()
            }
            
            if hasAnyRequirements {
                Text(form.requirementsSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(NSLocalizedString("poetryFormReference.about", comment: "About"))
            
            Text(form.description)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Requirements Section
    
    private var hasAnyRequirements: Bool {
        form.hasLineCountRequirement || form.hasSyllableRequirements || 
        form.hasRhymeScheme || form.hasMeterRequirements
    }
    
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(NSLocalizedString("poetryFormReference.requirements", comment: "Requirements"))
            
            VStack(spacing: 0) {
                if let lineCount = form.lineCount, lineCount > 0 {
                    requirementRow(
                        icon: "text.alignleft",
                        label: NSLocalizedString("poetryFormReference.lineCount", comment: "Line Count"),
                        value: "\(lineCount) lines"
                    )
                    
                    if form.hasSyllableRequirements || form.hasRhymeScheme || form.hasMeterRequirements {
                        Divider()
                    }
                }
                
                if let syllables = form.syllablePattern, !syllables.isEmpty {
                    requirementRow(
                        icon: "textformat.abc",
                        label: NSLocalizedString("poetryFormReference.syllablePattern", comment: "Syllable Pattern"),
                        value: formatSyllablePattern(syllables),
                        detail: syllablePatternDetail(syllables)
                    )
                    
                    if form.hasRhymeScheme || form.hasMeterRequirements {
                        Divider()
                    }
                }
                
                if let rhyme = form.rhymeScheme, !rhyme.isEmpty {
                    requirementRow(
                        icon: "text.quote",
                        label: NSLocalizedString("poetryFormReference.rhymeScheme", comment: "Rhyme Scheme"),
                        value: rhyme,
                        detail: rhymeSchemeDetail(rhyme)
                    )
                    
                    if form.hasMeterRequirements {
                        Divider()
                    }
                }
                
                if let meter = form.meterPattern, !meter.isEmpty {
                    requirementRow(
                        icon: "waveform.path",
                        label: NSLocalizedString("poetryFormReference.meter", comment: "Meter"),
                        value: meter.capitalized,
                        detail: meterDetail(meter)
                    )
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Template Section
    
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(NSLocalizedString("poetryFormReference.template", comment: "Template"))
            
            Text(form.templateContent)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
    
    private func requirementRow(icon: String, label: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            
            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }
        }
        .padding()
    }
    
    // MARK: - Formatting Helpers
    
    private var categoryColor: Color {
        switch form.category {
        case .japanese: return .orange
        case .rhymed: return .purple
        case .structured: return .mint
        case .metered: return .blue
        case .free: return .green
        case .custom: return .gray
        }
    }
    
    private func formatSyllablePattern(_ pattern: [Int]) -> String {
        pattern.map { String($0) }.joined(separator: "-")
    }
    
    private func syllablePatternDetail(_ pattern: [Int]) -> String? {
        let total = pattern.reduce(0, +)
        return String(format: NSLocalizedString("poetryFormReference.totalSyllables", comment: "Total syllables format"), total)
    }
    
    private func rhymeSchemeDetail(_ scheme: String) -> String? {
        // Count unique letters to determine number of different rhymes
        let letters = Set(scheme.uppercased().filter { $0.isLetter })
        if letters.count > 0 {
            return String(format: NSLocalizedString("poetryFormReference.uniqueRhymes", comment: "Unique rhymes format"), letters.count)
        }
        return nil
    }
    
    private func meterDetail(_ meter: String) -> String? {
        let lowerMeter = meter.lowercased()
        if lowerMeter.contains("iambic") {
            return NSLocalizedString("poetryFormReference.iambicDetail", comment: "Iambic explanation")
        } else if lowerMeter.contains("trochaic") {
            return NSLocalizedString("poetryFormReference.trochaicDetail", comment: "Trochaic explanation")
        } else if lowerMeter.contains("anapestic") {
            return NSLocalizedString("poetryFormReference.anapesticDetail", comment: "Anapestic explanation")
        } else if lowerMeter.contains("dactylic") {
            return NSLocalizedString("poetryFormReference.dactylicDetail", comment: "Dactylic explanation")
        }
        return nil
    }
}

// MARK: - Free Verse Reference

/// A simplified reference view for Free Verse (no requirements)
struct FreeVerseReference: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "text.alignleft")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text(NSLocalizedString("poetryFormReference.freeVerse.title", comment: "Free Verse"))
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(NSLocalizedString("poetryFormReference.freeVerse.description", comment: "Free Verse description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                Spacer()
            }
            .navigationTitle(NSLocalizedString("poetryFormReference.freeVerse.title", comment: "Free Verse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("poetryFormReference.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
