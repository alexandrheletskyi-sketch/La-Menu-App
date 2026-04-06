import SwiftUI

struct AppTypography: ViewModifier {
    let size: CGFloat
    let weight: AppFontWeight

    func body(content: Content) -> some View {
        content.font(.wix(size, weight))
    }
}

extension View {
    func appFont(_ size: CGFloat, _ weight: AppFontWeight = .regular) -> some View {
        modifier(AppTypography(size: size, weight: weight))
    }
}
