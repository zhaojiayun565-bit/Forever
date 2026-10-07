import Foundation
import Supabase

nonisolated enum DB {
    static let profiles = "profiles"
    static let couples = "couples"
    static let memories = "memories"
    static let notesBucket = "notes"
    static let drawingStrokes = "drawing_strokes"
    static let drawingArchive = "drawing_archive"
    static let cherishedTexts = "cherished_texts"
    static let cherishedTextsBucket = "cherished_texts_images"
    static let questionCategories = "question_categories"
    static let questions = "questions"
    static let coupleAnswers = "couple_answers"
}

nonisolated enum PairingError: LocalizedError {
    case emptyCode
    case partnerNotFound

    var errorDescription: String? {
        switch self {
        case .emptyCode: "Enter a pairing code."
        case .partnerNotFound: "No partner found with that code."
        }
    }
}

/// Wraps `SupabaseClient` for auth and table access. Feature areas live in `SupabaseManager+*.swift`.
nonisolated final class SupabaseManager: Sendable {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    private let coupleAnswersHub: CoupleAnswersRealtimeHub

    init(
        supabaseURL: URL = URL(string: "https://cdcnzkbxlyoxukxizfmd.supabase.co")!,
        supabaseKey: String = "sb_publishable_VygMgDm0S8and8KregtFyA_NF6tFRxK"
    ) {
        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true),
                realtime: .init(logLevel: .info)
            )
        )
        self.client = client
        coupleAnswersHub = CoupleAnswersRealtimeHub(client: client)
    }

    /// Unsubscribes and removes any cached channel for `topic`, then returns a fresh instance.
    func preparedRealtimeChannel(_ topic: String) async -> RealtimeChannelV2 {
        await tearDownRealtimeChannel(topic)
        return client.realtimeV2.channel(topic)
    }

    /// Unsubscribes and removes a cached channel for `topic` if one exists.
    func tearDownRealtimeChannel(_ topic: String) async {
        let existing = client.realtimeV2.channel(topic)
        await client.realtimeV2.removeChannel(existing)
    }

    /// Registers an observer on the shared couple-answers channel for `coupleId`.
    func observeCoupleAnswerChanges(
        coupleId: UUID,
        onChange: @escaping @MainActor @Sendable () async -> Void
    ) async -> UUID {
        await coupleAnswersHub.addObserver(coupleId: coupleId, onChange: onChange)
    }

    /// Removes a couple-answers observer; tears down the channel when the last observer detaches.
    func stopObservingCoupleAnswerChanges(token: UUID?) async {
        guard let token else { return }
        await coupleAnswersHub.removeObserver(token)
    }

    /// Returns the cached session if present; otherwise `nil` (does not throw for missing session).
    func getSession() async -> Session? {
        do {
            return try await client.auth.session
        } catch {
            return nil
        }
    }

    /// Returns the signed-in user's id, or nil when unauthenticated.
    func currentUserId() async -> UUID? {
        await getSession()?.user.id
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    #if DEBUG
    /// Creates an anonymous auth session and ensures a profile exists for pairing (debug builds only).
    func signInAnonymously() async throws -> String {
        let session = try await client.auth.signInAnonymously()
        let userId = session.user.id.uuidString
        try await createProfileIfMissing(userId: userId, fullName: "Anonymous Tester", avatarUrl: nil)
        return userId
    }
    #endif

    /// Whether the signed-in user authenticated with Sign in with Apple.
    func isSignedInWithApple() async -> Bool {
        guard let session = await getSession() else { return false }
        return session.user.identities?.contains { $0.provider == "apple" } == true
    }

    /// Permanently deletes the account server-side (data, files, Apple token, RevenueCat customer).
    func deleteAccount(appleAuthorizationCode: String?) async throws {
        struct Body: Encodable { let apple_authorization_code: String? }
        _ = try await client.auth.session
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(body: Body(apple_authorization_code: appleAuthorizationCode))
        )
        try? await client.auth.signOut(scope: .local)
    }

    /// Detaches this device's push token first so the partner's pushes stop arriving, then signs out.
    func signOut() async throws {
        try? await clearDeviceToken()
        try await client.auth.signOut()
    }

    static let iso8601Format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Extracts the object path from a Supabase public storage URL.
    static func storagePath(from url: URL, bucket: String) -> String? {
        let marker = "/storage/v1/object/public/\(bucket)/"
        let absolute = url.absoluteString
        guard let range = absolute.range(of: marker) else { return nil }
        return String(absolute[range.upperBound...])
    }
}
