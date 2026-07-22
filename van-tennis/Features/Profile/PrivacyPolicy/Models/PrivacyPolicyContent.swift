import Foundation

struct PrivacyPolicyContent: Decodable {
    let title: String
    let effectiveDate: String
    let lastUpdated: String
    let intro: [String]
    let sections: [PrivacyPolicySection]

    static let fallback = PrivacyPolicyContent(
        title: "Privacy Policy",
        effectiveDate: "",
        lastUpdated: "",
        intro: [],
        sections: []
    )

    static func loadFromBundle() -> PrivacyPolicyContent {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let content = try? JSONDecoder().decode(PrivacyPolicyContent.self, from: data) else {
            return fallback
        }

        return content
    }
}

struct PrivacyPolicySection: Decodable, Identifiable {
    let title: String
    let paragraphs: [String]
    let subsections: [PrivacyPolicySubsection]
    let bullets: [String]
    let bulletGroups: [PrivacyPolicyBulletGroup]
    let footer: [String]

    var id: String {
        title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case paragraphs
        case subsections
        case bullets
        case bulletGroups
        case footer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        paragraphs = try container.decodeIfPresent([String].self, forKey: .paragraphs) ?? []
        subsections = try container.decodeIfPresent([PrivacyPolicySubsection].self, forKey: .subsections) ?? []
        bullets = try container.decodeIfPresent([String].self, forKey: .bullets) ?? []
        bulletGroups = try container.decodeIfPresent([PrivacyPolicyBulletGroup].self, forKey: .bulletGroups) ?? []
        footer = try container.decodeIfPresent([String].self, forKey: .footer) ?? []
    }
}

struct PrivacyPolicySubsection: Decodable, Identifiable {
    let title: String
    let paragraphs: [String]
    let bullets: [String]
    let footer: [String]

    var id: String {
        title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case paragraphs
        case bullets
        case footer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        paragraphs = try container.decodeIfPresent([String].self, forKey: .paragraphs) ?? []
        bullets = try container.decodeIfPresent([String].self, forKey: .bullets) ?? []
        footer = try container.decodeIfPresent([String].self, forKey: .footer) ?? []
    }
}

struct PrivacyPolicyBulletGroup: Decodable, Identifiable {
    let title: String
    let bullets: [String]

    var id: String {
        title
    }
}
