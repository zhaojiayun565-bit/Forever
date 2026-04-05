import Foundation

// MARK: - Profile Model

/// Row in `profiles`; `CodingKeys` match Supabase snake_case (works with or without `convertFromSnakeCase`).
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var pairingCode: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pairingCode = "pairing_code"
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
