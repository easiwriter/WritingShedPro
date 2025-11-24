//
//  FootnoteRenderer.swift
//  Writing Shed Pro
//
//  Renders footnotes at the bottom of paginated pages
//  Uses professional typography standards (1.5" separator line, 10pt text)
//

import SwiftUI

/// Renders footnotes at the bottom of a paginated page
struct FootnoteRenderer: View {
    let footnotes: [FootnoteModel]
    let pageWidth: CGFloat
    let stylesheet: StyleSheet?
    
    // Get the footnote style from stylesheet
    private var footnoteStyle: TextStyleModel? {
        let styleName = UIFont.TextStyle.footnote.rawValue
        return stylesheet?.textStyles?.first { $0.name == styleName }
    }
    
    // Font size for footnotes (from stylesheet or default 10pt)
    private var footnoteFontSize: CGFloat {
        footnoteStyle?.fontSize ?? 10
    }
    
    // Font for footnotes
    private var footnoteFont: Font {
        if let style = footnoteStyle {
            let size = style.fontSize
            let weight: Font.Weight = style.isBold ? .bold : .regular
            return .system(size: size, weight: weight)
        }
        return .system(size: 10)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Separator section with 10pt space above
            Spacer()
                .frame(height: 10)
            
            // 1.5-inch separator line (108 points)
            Rectangle()
                .fill(Color.primary)
                .frame(width: 108, height: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 10pt space below separator
            Spacer()
                .frame(height: 10)
            
            // Footnote entries
            VStack(alignment: .leading, spacing: 4) {
                ForEach(footnotes) { footnote in
                    footnoteEntry(footnote)
                }
            }
        }
        .frame(width: pageWidth)
        .background(Color(UIColor.systemBackground))
    }
    
    @ViewBuilder
    private func footnoteEntry(_ footnote: FootnoteModel) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Superscript number (slightly smaller than body text)
            Text("\(footnote.number)")
                .font(.system(size: footnoteFontSize * 0.9))
                .baselineOffset(4)
                .foregroundStyle(footnoteStyle?.textColor.map { Color($0) } ?? .primary)
            
            // Footnote text (respects stylesheet - all attributes)
            Text(footnote.text)
                .font(footnoteFont)
                .italic(footnoteStyle?.isItalic ?? false)
                .underline(footnoteStyle?.isUnderlined ?? false)
                .strikethrough(footnoteStyle?.isStrikethrough ?? false)
                .foregroundStyle(footnoteStyle?.textColor.map { Color($0) } ?? .primary)
                .lineSpacing(1.2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
