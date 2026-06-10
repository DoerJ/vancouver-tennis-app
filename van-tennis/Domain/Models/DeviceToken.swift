import Foundation

struct NewDeviceToken: Encodable {
    let userID: UUID
    let deviceToken: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case deviceToken = "device_token"
        case platform
    }
}
