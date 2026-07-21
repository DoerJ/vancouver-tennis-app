import Foundation

struct TermsOfServiceContent: Decodable {
    let title: String
    let effectiveDate: String
    let lastUpdated: String
    let intro: [String]
    let sections: [TermsOfServiceSection]

    static let fallback = TermsOfServiceContent(
        title: "Terms of Service",
        effectiveDate: "",
        lastUpdated: "",
        intro: [],
        sections: []
    )

    static func loadFromBundle() -> TermsOfServiceContent {
        guard let url = Bundle.main.url(forResource: "TermsOfService", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let content = try? JSONDecoder().decode(TermsOfServiceContent.self, from: data) else {
            return fallback
        }

        return content
    }
}

struct TermsOfServiceSection: Decodable, Identifiable {
    let title: String
    let paragraphs: [String]
    let bullets: [String]
    let bulletGroups: [TermsOfServiceBulletGroup]
    let footer: [String]

    var id: String {
        title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case paragraphs
        case bullets
        case bulletGroups
        case footer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        paragraphs = try container.decodeIfPresent([String].self, forKey: .paragraphs) ?? []
        bullets = try container.decodeIfPresent([String].self, forKey: .bullets) ?? []
        bulletGroups = try container.decodeIfPresent([TermsOfServiceBulletGroup].self, forKey: .bulletGroups) ?? []
        footer = try container.decodeIfPresent([String].self, forKey: .footer) ?? []
    }
}

struct TermsOfServiceBulletGroup: Decodable, Identifiable {
    let title: String
    let bullets: [String]

    var id: String {
        title
    }
}
