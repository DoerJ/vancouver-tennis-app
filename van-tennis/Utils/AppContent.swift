import Foundation

enum AppContent {
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let template = lookup(key) ?? key

        guard !arguments.isEmpty else {
            return template
        }

        return String(format: template, locale: Locale.current, arguments: arguments)
    }

    private static func lookup(_ key: String) -> String? {
        var current: Any? = content

        for component in key.split(separator: ".").map(String.init) {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }

            current = dictionary[component]
        }

        return current as? String
    }

    private static let content: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "AppContent", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data),
            let content = object as? [String: Any]
        else {
            return [:]
        }

        return content
    }()
}
