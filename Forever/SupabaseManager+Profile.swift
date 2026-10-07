import Foundation
import Supabase

// Profile rows: creation, location, push token, avatar and details.
extension SupabaseManager {
    /// Loads the profile row for the signed-in user, if it exists.
    func fetchProfile() async throws -> Profile? {
        let session = try await client.auth.session
        let rows: [Profile] = try await client.from(DB.profiles)
            .select()
            .eq("id", value: session.user.id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Inserts a profile for the current user with the given pairing code.
    func createProfile(code: String) async throws {
        let session = try await client.auth.session
        try await client.from(DB.profiles)
            .insert(NewProfileInsert(id: session.user.id, pairing_code: code))
            .execute()
    }

    /// Ensures a profile row exists for the provided user id.
    func createProfileIfMissing(userId: String, fullName: String, avatarUrl: String?) async throws {
        _ = avatarUrl
        guard let uuid = UUID(uuidString: userId) else { return }
        let existing: [Profile] = try await client.from(DB.profiles)
            .select()
            .eq("id", value: uuid)
            .limit(1)
            .execute()
            .value
        guard existing.first == nil else { return }

        for _ in 0 ..< 10 {
            do {
                try await client.from(DB.profiles)
                    .insert(ProfileInsertWithName(
                        id: uuid,
                        pairing_code: Self.randomSixDigitCode(),
                        display_name: fullName
                    ))
                    .execute()
                return
            } catch {
                continue
            }
        }

        try await client.from(DB.profiles)
            .insert(ProfileInsertWithName(
                id: uuid,
                pairing_code: Self.randomSixDigitCode(),
                display_name: fullName
            ))
            .execute()
    }

    /// Uploads location + battery; the server stamps and returns `location_updated_at`.
    @discardableResult
    func updateAmbientData(latitude: Double, longitude: Double, batteryLevel: Int) async throws -> Date {
        _ = try await client.auth.session
        return try await client
            .rpc("update_my_location", params: AmbientDataUpdate(
                p_latitude: latitude,
                p_longitude: longitude,
                p_battery_level: batteryLevel
            ))
            .execute()
            .value
    }

    /// Saves this device's APNs token with its environment so the server picks the matching APNs host.
    func updateDeviceToken(_ token: String) async throws {
        let session = try await client.auth.session
        try await client.from(DB.profiles)
            .update(DeviceTokenUpdateDTO(device_token: token, apns_environment: APNsEnvironment.current.rawValue))
            .eq("id", value: session.user.id)
            .execute()
    }

    /// Removes the push token from the profile (sign-out) so no more pushes target this device.
    func clearDeviceToken() async throws {
        let session = try await client.auth.session
        try await client.from(DB.profiles)
            .update(DeviceTokenUpdateDTO(device_token: nil, apns_environment: nil))
            .eq("id", value: session.user.id)
            .execute()
    }

    /// Persists the device IANA timezone for backend streak reminders.
    func updateTimezone(_ timezone: String) async throws {
        let session = try await client.auth.session
        try await client.from(DB.profiles)
            .update(TimezoneUpdateDTO(timezone: timezone))
            .eq("id", value: session.user.id)
            .execute()
    }

    /// Uploads a profile photo and saves its public URL on the signed-in user's profile.
    /// Uploads the avatar photo and returns the updated profile.
    func uploadProfileAvatar(_ imageData: Data) async throws -> Profile {
        let session = try await client.auth.session
        let path = "avatars/\(session.user.id.uuidString).jpg"

        try await client.storage
            .from(DB.notesBucket)
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        let publicUrl = try client.storage.from(DB.notesBucket).getPublicURL(path: path)
        return try await setAvatarUrl(publicUrl.absoluteString, userId: session.user.id)
    }

    /// Deletes the signed-in user's profile photo from storage and clears `avatar_url`.
    func removeProfileAvatar() async throws -> Profile {
        let session = try await client.auth.session
        let path = "avatars/\(session.user.id.uuidString).jpg"

        _ = try? await client.storage
            .from(DB.notesBucket)
            .remove(paths: [path])

        return try await setAvatarUrl(nil, userId: session.user.id)
    }

    /// Writes `avatar_url` (an explicit null clears it) and returns the updated profile.
    private func setAvatarUrl(_ url: String?, userId: UUID) async throws -> Profile {
        struct AvatarUpdate: Encodable, Sendable {
            let avatar_url: String?

            enum CodingKeys: String, CodingKey { case avatar_url }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(avatar_url, forKey: .avatar_url)
            }
        }
        return try await client.from(DB.profiles)
            .update(AvatarUpdate(avatar_url: url))
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
    }

    /// Updates display name, partner nickname, and anniversary date; returns the updated profile.
    func updateProfileDetails(name: String, partnerNickname: String?, anniversary: Date) async throws -> Profile {
        let session = try await client.auth.session
        struct UpdateDTO: Encodable, Sendable {
            let display_name: String
            let partner_nickname: String?
            let anniversary_date: Date

            enum CodingKeys: String, CodingKey { case display_name, partner_nickname, anniversary_date }

            /// Encodes a nil nickname as null so clearing it actually clears the column.
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(display_name, forKey: .display_name)
                try container.encode(partner_nickname, forKey: .partner_nickname)
                try container.encode(anniversary_date, forKey: .anniversary_date)
            }
        }
        let trimmedNickname = partnerNickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nicknameToSave = (trimmedNickname?.isEmpty == false) ? trimmedNickname : nil
        return try await client.from(DB.profiles)
            .update(UpdateDTO(
                display_name: name,
                partner_nickname: nicknameToSave,
                anniversary_date: anniversary
            ))
            .eq("id", value: session.user.id)
            .select()
            .single()
            .execute()
            .value
    }

    /// Asks the server to re-derive this user's premium state from RevenueCat (clients can't write it).
    func syncPremiumStatus() async throws {
        _ = try await client.auth.session
        try await client.functions.invoke("revenuecat-sync")
    }

    /// Sends a lock screen message for the signed-in user.
    func sendLockScreenMessage(_ message: String) async throws {
        let session = try await client.auth.session
        struct MsgDTO: Encodable, Sendable {
            let latest_message: String
        }
        try await client.from(DB.profiles)
            .update(MsgDTO(latest_message: message))
            .eq("id", value: session.user.id)
            .execute()
    }

    static func randomSixDigitCode() -> String {
        String(format: "%06d", Int.random(in: 0 ... 999_999))
    }
}

// MARK: - DTOs

private nonisolated struct NewProfileInsert: Encodable, Sendable {
    let id: UUID
    let pairing_code: String
}

private nonisolated struct ProfileInsertWithName: Encodable, Sendable {
    let id: UUID
    let pairing_code: String
    let display_name: String
}

private nonisolated struct AmbientDataUpdate: Encodable, Sendable {
    let p_latitude: Double
    let p_longitude: Double
    let p_battery_level: Int
}

private nonisolated struct TimezoneUpdateDTO: Encodable, Sendable {
    let timezone: String
}

private nonisolated struct DeviceTokenUpdateDTO: Encodable, Sendable {
    let device_token: String?
    let apns_environment: String?

    /// Encodes nils as JSON null so clearing actually nulls the columns.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(device_token, forKey: .device_token)
        try container.encode(apns_environment, forKey: .apns_environment)
    }

    private enum CodingKeys: String, CodingKey {
        case device_token, apns_environment
    }
}
