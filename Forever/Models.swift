import Foundation

// MARK: - Profile Model

/// Row in `profiles`; `CodingKeys` match Supabase snake_case (works with or without `convertFromSnakeCase`).
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var pairingCode: String?
    var latitude: Double?
    var longitude: Double?
    var batteryLevel: Int?
    var latestNoteUrl: String?
    var deviceToken: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pairingCode = "pairing_code"
        case latitude
        case longitude
        case batteryLevel = "battery_level"
        case latestNoteUrl = "latest_note_url"
        case deviceToken = "device_token"
        case createdAt = "created_at"
    }
}

// MARK: - Couple Model

/// Row in `couples`.
struct Couple: Codable, Identifiable, Hashable {
    let id: UUID
    let user1Id: UUID
    let user2Id: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
    }
}

// MARK: - Mocks for Previews

extension Profile {
    static let mock = Profile(
        id: UUID(),
        pairingCode: "XJ92KL",
        latitude: 37.3349,
        longitude: -122.0090,
        batteryLevel: 85,
        latestNoteUrl: nil,
        deviceToken: nil,
        createdAt: Date()
    )
}

extension Couple {
    static let mock = Couple(
        id: UUID(),
        user1Id: UUID(),
        user2Id: UUID(),
        createdAt: Date()
    )
}
