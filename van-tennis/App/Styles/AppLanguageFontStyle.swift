import SwiftUI

extension Font {
    private static let mandarinFontName = "NotoSansTC-Thin"

    static func rally(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard AppContent.currentLanguage == .mandarinSimplified else {
            return .system(size: size, weight: weight)
        }

        return .custom(mandarinFontName, size: size).weight(weight)
    }
}

private struct AppLanguageFontStyle: ViewModifier {
    let language: AppContent.Language

    @ViewBuilder
    func body(content: Content) -> some View {
        if language == .mandarinSimplified {
            content.font(.custom("NotoSansTC-Thin", size: 15))
        } else {
            content
        }
    }
}

extension View {
    func appLanguageFontStyle(_ language: AppContent.Language) -> some View {
        modifier(AppLanguageFontStyle(language: language))
    }
}
