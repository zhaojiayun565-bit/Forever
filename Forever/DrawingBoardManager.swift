import Foundation
import Observation
import Supabase
import SwiftUI

/// Owns the shared drawing board's state and Supabase sync.
///
/// Sync is hybrid: a Realtime **Broadcast** channel delivers live, throttled, incremental
/// point chunks (low latency), while the `drawing_strokes` table persists completed strokes
/// (durable reload). In-progress remote strokes are tracked **per author** so both partners
/// can draw simultaneously without clobbering each other.
@MainActor
@Observable
final class DrawingBoardManager {
    private let supabase: SupabaseManager
    private let coupleId: UUID?
    let currentUserId: UUID
    private let partnerName: String

    /// Finished strokes (loaded + remote-finalized + local-committed), rendered bottom-to-top.
    var committedStrokes: [DrawStroke] = []
    /// Live remote strokes still being drawn, keyed by `authorId` to avoid cross-user clobbering.
    var remoteActiveStrokes: [UUID: DrawStroke] = [:]
    /// Non-nil while an in-app banner should be shown for a partner update.
    var toastMessage: String?
    var isLoading = true

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    // Outgoing broadcast throttle state.
    private var flushTask: Task<Void, Never>?
    private var activeStrokeId: UUID?
    private var pendingColorHex = "#FFFFFF"
    private var pendingWidth: Double = 0
    private var pendingPoints: [CGPoint] = []

    /// ~70ms throttle caps broadcasts at roughly 14/sec regardless of gesture frequency.
    private let flushInterval: Duration = .milliseconds(70)

    init(
        coupleId: UUID?,
        currentUserId: UUID,
        partnerName: String,
        supabase: SupabaseManager = .shared
    ) {
        self.coupleId = coupleId
        self.currentUserId = currentUserId
        self.partnerName = partnerName
        self.supabase = supabase
    }

    // MARK: - Lifecycle

    /// Subscribes to the board channel and loads persisted strokes. Solo (unpaired) users
    /// get a local-only board with no channel or persistence.
    func start() async {
        isLoading = true
        defer { isLoading = false }
        guard let coupleId else { return }

        let channel = supabase.client.realtimeV2.channel("drawing-board-\(coupleId.uuidString)")
        self.channel = channel

        // Register broadcast listeners BEFORE subscribing so no early messages are missed.
        let strokeStream = channel.broadcastStream(event: BoardEvent.stroke)
        let undoStream = channel.broadcastStream(event: BoardEvent.undo)
        let clearStream = channel.broadcastStream(event: BoardEvent.clear)

        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await json in strokeStream { await self?.handleStroke(json) } }
                group.addTask { for await json in undoStream { await self?.handleUndo(json) } }
                group.addTask { for await json in clearStream { await self?.handleClear(json) } }
            }
        }

        // Observe every status transition for the lifetime of the board.
        let statusStream = channel.statusChange
        Task {
            for await status in statusStream {
                print("🎨 [board] channel status -> \(status)")
            }
        }

        do {
            try await channel.subscribeWithError()
            print("🎨 [board] subscribed OK. topic=\(channel.topic) status=\(channel.status)")
        } catch {
            print("🚨 [board] subscribe FAILED: \(error)")
        }
        await loadExisting(coupleId: coupleId)
    }

    /// Cancels tasks and tears down the channel.
    func stop() async {
        flushTask?.cancel()
        listenTask?.cancel()
        toastTask?.cancel()
        if let channel {
            await supabase.client.realtimeV2.removeChannel(channel)
        }
        channel = nil
    }

    private func loadExisting(coupleId: UUID) async {
        do {
            committedStrokes = try await supabase.fetchStrokes(coupleId: coupleId)
        } catch {
            print("🚨 Failed to load board strokes: \(error)")
        }
    }

    // MARK: - Local drawing (called by the canvas)

    /// Enqueues newly drawn points for throttled broadcast. Mutates only private buffers,
    /// so the surrounding UI never re-renders mid-stroke.
    func enqueueLocalPoints(strokeId: UUID, colorHex: String, width: Double, newPoints: [CGPoint]) {
        guard channel != nil else { return }
        if activeStrokeId != strokeId {
            activeStrokeId = strokeId
            pendingColorHex = colorHex
            pendingWidth = width
            pendingPoints = []
        }
        pendingPoints.append(contentsOf: newPoints)
        scheduleFlush()
    }

    /// Finalizes a local stroke: flushes the last chunk, commits locally, and persists once.
    func commitLocalStroke(_ stroke: DrawStroke) async {
        committedStrokes.append(stroke)
        flushTask?.cancel()
        flushTask = nil
        await flush(isFinal: true)

        guard let coupleId else { return }
        do {
            let payload = DrawingStrokeInsert(coupleId: coupleId, stroke: stroke)
            try await supabase.insertStroke(payload)
        } catch {
            print("🚨 Failed to persist stroke: \(error)")
        }
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: self?.flushInterval ?? .milliseconds(70))
            guard !Task.isCancelled else { return }
            await self?.flush(isFinal: false)
            self?.flushTask = nil
        }
    }

    private func flush(isFinal: Bool) async {
        guard let channel, let strokeId = activeStrokeId else { return }
        let points = pendingPoints
        pendingPoints = []
        guard !points.isEmpty || isFinal else { return }

        let payload = StrokeChunkPayload(
            strokeId: strokeId,
            authorId: currentUserId,
            colorHex: pendingColorHex,
            width: pendingWidth,
            points: points.flattened,
            isFinal: isFinal
        )
        print("🎨 [board] SEND stroke pts=\(points.count) final=\(isFinal) status=\(channel.status)")
        do {
            try await channel.broadcast(event: BoardEvent.stroke, message: payload)
        } catch {
            print("🚨 [board] broadcast send failed: \(error)")
        }
        if isFinal { activeStrokeId = nil }
    }

    // MARK: - Toolbar actions

    /// Removes the current user's most recent stroke, locally and remotely.
    func undoLast() async {
        guard let last = committedStrokes.last(where: { $0.authorId == currentUserId }) else { return }
        committedStrokes.removeAll { $0.id == last.id }
        guard let channel else { return }
        do {
            try await supabase.deleteStroke(id: last.id)
            try await channel.broadcast(
                event: BoardEvent.undo,
                message: BoardControlPayload(authorId: currentUserId, strokeId: last.id)
            )
        } catch {
            print("🚨 Undo failed: \(error)")
        }
    }

    /// Wipes the entire board, locally and remotely.
    func clearAll() async {
        committedStrokes.removeAll()
        remoteActiveStrokes.removeAll()
        guard let coupleId, let channel else { return }
        do {
            try await supabase.clearStrokes(coupleId: coupleId)
            try await channel.broadcast(
                event: BoardEvent.clear,
                message: BoardControlPayload(authorId: currentUserId, strokeId: nil)
            )
        } catch {
            print("🚨 Clear failed: \(error)")
        }
    }

    /// True when the current user has at least one stroke to undo.
    var canUndo: Bool {
        committedStrokes.contains { $0.authorId == currentUserId }
    }

    // MARK: - Incoming broadcast handlers

    private func handleStroke(_ json: JSONObject) {
        print("🎨 [board] RECV raw=\(json)")
        let chunk: StrokeChunkPayload
        do {
            guard let decoded = try json["payload"]?.decode(as: StrokeChunkPayload.self) else {
                print("🚨 [board] RECV missing payload key")
                return
            }
            chunk = decoded
        } catch {
            print("🚨 [board] RECV decode failed: \(error)")
            return
        }
        let newPoints = chunk.points.toCGPoints()

        if var existing = remoteActiveStrokes[chunk.authorId], existing.id == chunk.strokeId {
            existing.points.append(contentsOf: newPoints)
            if chunk.isFinal {
                remoteActiveStrokes[chunk.authorId] = nil
                committedStrokes.append(existing)
                triggerToast()
            } else {
                remoteActiveStrokes[chunk.authorId] = existing
            }
        } else {
            let stroke = DrawStroke(
                id: chunk.strokeId,
                authorId: chunk.authorId,
                colorHex: chunk.colorHex,
                width: chunk.width,
                points: newPoints
            )
            if chunk.isFinal {
                committedStrokes.append(stroke)
                triggerToast()
            } else {
                remoteActiveStrokes[chunk.authorId] = stroke
            }
        }
    }

    private func handleUndo(_ json: JSONObject) {
        print("🎨 [board] RECV undo")
        guard
            let payload = try? json["payload"]?.decode(as: BoardControlPayload.self),
            let strokeId = payload.strokeId
        else { return }
        committedStrokes.removeAll { $0.id == strokeId }
    }

    private func handleClear(_ json: JSONObject) {
        print("🎨 [board] RECV clear")
        committedStrokes.removeAll()
        remoteActiveStrokes.removeAll()
    }

    private func triggerToast() {
        toastMessage = String(localized: "\(partnerName) added to your board")
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
