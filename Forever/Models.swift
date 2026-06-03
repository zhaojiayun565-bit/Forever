import CoreLocation
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
    var displayName: String?
    var avatarUrl: String?
    var latestMessage: String?
    var anniversaryDate: Date?
    var deviceToken: String?
    var isPremium: Bool?
    var premiumExpiresAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pairingCode = "pairing_code"
        case latitude
        case longitude
        case batteryLevel = "battery_level"
        case latestNoteUrl = "latest_note_url"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case latestMessage = "latest_message"
        case anniversaryDate = "anniversary_date"
        case deviceToken = "device_token"
        case isPremium = "is_premium"
        case premiumExpiresAt = "premium_expires_at"
        case createdAt = "created_at"
    }

    /// Whether this profile row represents an active premium subscription.
    var isPremiumActive: Bool {
        guard isPremium == true else { return false }
        if let expires = premiumExpiresAt, expires < Date() { return false }
        return true
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

// MARK: - Memory Model

struct CoupleMemory: Identifiable, Equatable, Hashable {
    let id: UUID
    /// `nil` for memories saved in Solo Mode before pairing.
    let coupleId: UUID?
    let creatorId: UUID
    let imageUrls: [URL]
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    let note: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Archived Drawing

/// A sent drawing-board snapshot stored in the shared archive.
struct ArchivedDrawing: Identifiable, Equatable, Hashable {
    let id: UUID
    let authorId: UUID
    let imageUrl: URL
    let createdAt: Date
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
        displayName: "Taylor",
        latestMessage: "Thinking of you",
        anniversaryDate: Date(),
        deviceToken: nil,
        isPremium: false,
        premiumExpiresAt: nil,
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
