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
            return "Male"
        case .female:
            return "Female"
        case .nonBinary:
            return "Non-binary"
        case .preferNotToSay:
            return "Prefer not to say"
        }
    }
}
