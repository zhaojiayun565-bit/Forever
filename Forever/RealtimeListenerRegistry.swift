import Foundation
import Supabase

/// Keeps at most one Realtime subscription per topic alive.
/// - Restarting a topic waits for the previous channel to finish tearing down, so a stale teardown
///   can never remove the newer channel (the SDK caches and removes channels by topic).
/// - Failed or dropped subscriptions retry with backoff until stopped.
/// - Listener work runs inside the subscription task, so stopping it cancels everything it started.
@MainActor
final class RealtimeListenerRegistry {
    /// Registers change streams on the channel (before subscribing) and returns the loop that consumes them.
    typealias Register = @MainActor (RealtimeChannelV2) -> @MainActor () async -> Void

    private static let maxBackoff: Duration = .seconds(30)

    private let supabase: SupabaseManager
    private var tasks: [String: Task<Void, Never>] = [:]

    init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    /// Starts (or restarts) the listener for `topic`.
    func start(_ topic: String, register: @escaping Register) {
        let previous = tasks[topic]
        previous?.cancel()
        tasks[topic] = Task { [supabase] in
            await previous?.value
            var backoff: Duration = .seconds(1)

            while !Task.isCancelled {
                let channel = await supabase.preparedRealtimeChannel(topic)
                let consume = register(channel)
                do {
                    try await channel.subscribeWithError()
                    backoff = .seconds(1)
                    await consume()
                } catch {
                    print("🚨 Realtime subscribe failed for \(topic): \(error)")
                }
                await supabase.tearDownRealtimeChannel(topic)

                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, Self.maxBackoff)
            }
        }
    }

    /// Stops the listener for `topic`. The cancelled task stays registered so a later `start` still
    /// waits for its teardown.
    func stop(_ topic: String) {
        tasks[topic]?.cancel()
    }

    /// Stops listeners whose topic doesn't satisfy `keep`.
    func stopAll(except keep: (String) -> Bool = { _ in false }) async {
        let stopping = tasks.filter { !keep($0.key) }
        stopping.keys.forEach { tasks.removeValue(forKey: $0) }
        stopping.values.forEach { $0.cancel() }
        for task in stopping.values {
            await task.value
        }
    }
}
