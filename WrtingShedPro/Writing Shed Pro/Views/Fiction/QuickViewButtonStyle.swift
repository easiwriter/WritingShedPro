import SwiftUI

struct QuickViewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: configuration.isPressed ? 2 : 1)
            )
            .foregroundColor(.accentColor)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
