import Foundation

enum Gender: String, CaseIterable, Codable, Identifiable {
    case male
    case female
    case nonBinary = "non_binary"
    case preferNotToSay = "prefer_not_to_say"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .male:
            return AppContent.string("gender.male")
        case .female:
            return AppContent.string("gender.female")
        case .nonBinary:
            return AppContent.string("gender.nonBinary")
        case .preferNotToSay:
            return AppContent.string("gender.preferNotToSay")
        }
    }
}
