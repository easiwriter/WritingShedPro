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
    }
    
    @ViewBuilder
    private func footnoteEntry(_ footnote: FootnoteModel) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Superscript number
            Text("\(footnote.number)")
                .font(.system(size: 10))
                .baselineOffset(4)
                .foregroundStyle(.primary)
            
            // Footnote text
            Text(footnote.text)
                .font(.system(size: 10))
                .lineSpacing(1.2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
