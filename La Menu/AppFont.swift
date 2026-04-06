import SwiftUI

enum AppFontWeight {
    case regular
    case medium
    case semibold
    case bold
    case extraBold

    var name: String {
        switch self {
        case .regular:
            return "WixMadeforDisplay-Regular"
        case .medium:
            return "WixMadeforDisplay-Medium"
        case .semibold:
            return "WixMadeforDisplay-SemiBold"
        case .bold:
            return "WixMadeforDisplay-Bold"
        case .extraBold:
            return "WixMadeforDisplay-ExtraBold"
        }
    }
}

extension Font {
    static func wix(_ size: CGFloat, _ weight: AppFontWeight = .regular) -> Font {
        .custom(weight.name, size: size)
    }
}
