enum SkillLevel: String, CaseIterable, Codable, Identifiable, Hashable {
    case one = "1.0"
    case two = "2.0"
    case three = "3.0"
    case four = "4.0"

    var id: String {
        rawValue
    }
}
