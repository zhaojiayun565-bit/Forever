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
    var partnerNickname: String?
    var avatarUrl: String?
    var latestMessage: String?
    var anniversaryDate: Date?
    var deviceToken: String?
    var isPremium: Bool?
    var premiumExpiresAt: Date?
    var timezone: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pairingCode = "pairing_code"
        case latitude
        case longitude
        case batteryLevel = "battery_level"
        case latestNoteUrl = "latest_note_url"
        case displayName = "display_name"
        case partnerNickname = "partner_nickname"
        case avatarUrl = "avatar_url"
        case latestMessage = "latest_message"
        case anniversaryDate = "anniversary_date"
        case deviceToken = "device_token"
        case isPremium = "is_premium"
        case premiumExpiresAt = "premium_expires_at"
        case timezone
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
    var boardWallpaperUrl: String?
    var questionsStreakCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case boardWallpaperUrl = "board_wallpaper_url"
        case questionsStreakCount = "questions_streak_count"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        user1Id: UUID,
        user2Id: UUID,
        boardWallpaperUrl: String? = nil,
        questionsStreakCount: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.boardWallpaperUrl = boardWallpaperUrl
        self.questionsStreakCount = questionsStreakCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user1Id = try container.decode(UUID.self, forKey: .user1Id)
        user2Id = try container.decode(UUID.self, forKey: .user2Id)
        boardWallpaperUrl = try container.decodeIfPresent(String.self, forKey: .boardWallpaperUrl)
        questionsStreakCount = try container.decodeIfPresent(Int.self, forKey: .questionsStreakCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
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

// MARK: - Questions

/// Row in `question_categories`.
struct QuestionCategory: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String?
    let iconName: String?
    let isPremium: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case iconName = "icon_name"
        case isPremium = "is_premium"
        case sortOrder = "sort_order"
    }
}

/// Row in `questions`.
struct Question: Codable, Identifiable, Hashable {
    let id: UUID
    let categoryId: UUID
    let questionText: String
    let isDaily: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case questionText = "question_text"
        case isDaily = "is_daily"
    }
}

/// Row in `couple_answers`; partner_a maps to user1, partner_b to user2.
struct CoupleAnswer: Codable, Identifiable, Hashable {
    let id: UUID
    let coupleId: UUID
    let questionId: UUID
    let partnerAId: UUID
    var partnerAResponse: String?
    var partnerAAnsweredAt: Date?
    let partnerBId: UUID
    var partnerBResponse: String?
    var partnerBAnsweredAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case questionId = "question_id"
        case partnerAId = "partner_a_id"
        case partnerAResponse = "partner_a_response"
        case partnerAAnsweredAt = "partner_a_answered_at"
        case partnerBId = "partner_b_id"
        case partnerBResponse = "partner_b_response"
        case partnerBAnsweredAt = "partner_b_answered_at"
    }

    /// Whether both partners have submitted an answer.
    var isRevealed: Bool {
        partnerAAnsweredAt != nil && partnerBAnsweredAt != nil
    }

    /// The current user's saved response, if any.
    func myResponse(for userId: UUID) -> String? {
        if userId == partnerAId { return partnerAResponse }
        if userId == partnerBId { return partnerBResponse }
        return nil
    }

    /// The partner's response (only meaningful once revealed).
    func partnerResponse(for userId: UUID) -> String? {
        if userId == partnerAId { return partnerBResponse }
        if userId == partnerBId { return partnerAResponse }
        return nil
    }

    /// Whether the given user has already answered.
    func hasAnswered(userId: UUID) -> Bool {
        if userId == partnerAId { return partnerAAnsweredAt != nil }
        if userId == partnerBId { return partnerBAnsweredAt != nil }
        return false
    }

    /// Whether either partner submitted an answer on the given UTC calendar day.
    func wasAnsweredOnUTC(day: Date = .now) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return [partnerAAnsweredAt, partnerBAnsweredAt].compactMap { $0 }.contains {
            calendar.isDate($0, inSameDayAs: day)
        }
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
        partnerNickname: nil,
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
        boardWallpaperUrl: nil,
        questionsStreakCount: 0,
        createdAt: Date()
    )
}
