import Foundation

enum AppContent {
    enum Language: String {
        case english
        case mandarinSimplified

        var resourceName: String {
            switch self {
            case .english:
                return "AppContent"
            case .mandarinSimplified:
                return "AppContent.zh-Hans"
            }
        }

        var locale: Locale {
            switch self {
            case .english:
                return Locale(identifier: "en")
            case .mandarinSimplified:
                return Locale(identifier: "zh-Hans")
            }
        }
    }

    private static let selectedLanguageKey = "selectedAppContentLanguage"
    private static var cachedContentByLanguage: [Language: [String: Any]] = [:]
    private static var activeLanguage: Language = {
        guard let rawValue = UserDefaults.standard.string(forKey: selectedLanguageKey),
              let language = Language(rawValue: rawValue) else {
            return .english
        }

        return language
    }()

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let template = lookup(key) ?? key

        guard !arguments.isEmpty else {
            return template
        }

        return String(format: template, locale: activeLanguage.locale, arguments: arguments)
    }

    static var currentLanguage: Language {
        activeLanguage
    }

    static func setLanguage(_ language: Language) {
        activeLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: selectedLanguageKey)
    }

    private static func lookup(_ key: String) -> String? {
        if let localized = lookup(key, in: content(for: activeLanguage)) {
            return localized
        }

        guard activeLanguage != .english else {
            return nil
        }

        return lookup(key, in: content(for: .english))
    }

    private static func lookup(_ key: String, in content: [String: Any]) -> String? {
        var current: Any? = content

        for component in key.split(separator: ".").map(String.init) {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }

            current = dictionary[component]
        }

        return current as? String
    }

    private static func content(for language: Language) -> [String: Any] {
        if let cachedContent = cachedContentByLanguage[language] {
            return cachedContent
        }

        let loadedContent = loadContent(resourceName: language.resourceName)
        cachedContentByLanguage[language] = loadedContent
        return loadedContent
    }

    private static func loadContent(resourceName: String) -> [String: Any] {
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data),
            let content = object as? [String: Any]
        else {
            return [:]
        }

        return content
    }
}
