enum SkillLevel: String, CaseIterable, Codable, Identifiable, Hashable {
    case one = "1.0"
    case oneFive = "1.5"
    case two = "2.0"
    case twoFive = "2.5"
    case three = "3.0"
    case threeFive = "3.5"
    case four = "4.0"

    var id: String {
        rawValue
    }
}
