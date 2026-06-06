import Foundation
import Observation
import Supabase
import SwiftUI
import UIKit

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
    /// Shared board background, synced per couple via storage + realtime broadcast.
    var wallpaper: UIImage?
    var wallpaperUrl: String?
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

    /// Ensures the "started drawing" push fires at most once per board session.
    private var didSignalStart = false

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
        if channel != nil {
            await stop()
        }

        isLoading = true
        defer { isLoading = false }
        guard let coupleId else { return }

        let topic = "drawing-board-\(coupleId.uuidString)"
        let channel = await supabase.preparedRealtimeChannel(topic)
        self.channel = channel

        // Register broadcast listeners BEFORE subscribing so no early messages are missed.
        let strokeStream = channel.broadcastStream(event: BoardEvent.stroke)
        let undoStream = channel.broadcastStream(event: BoardEvent.undo)
        let clearStream = channel.broadcastStream(event: BoardEvent.clear)
        let wallpaperStream = channel.broadcastStream(event: BoardEvent.wallpaper)

        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await json in strokeStream { await self?.handleStroke(json) } }
                group.addTask { for await json in undoStream { await self?.handleUndo(json) } }
                group.addTask { for await json in clearStream { await self?.handleClear(json) } }
                group.addTask { for await json in wallpaperStream { await self?.handleWallpaper(json) } }
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
        didSignalStart = false
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
        do {
            let couple = try await supabase.fetchCouple(id: coupleId)
            if let url = couple.boardWallpaperUrl {
                wallpaperUrl = url
                wallpaper = await downloadWallpaper(from: url)
            }
        } catch {
            print("🚨 Failed to load board wallpaper: \(error)")
        }
    }

    /// Sets the shared board wallpaper locally, uploads it, persists on the couple, and broadcasts.
    func setWallpaper(_ image: UIImage) async {
        wallpaper = image
        guard let coupleId else { return }
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }

        do {
            let url = try await supabase.uploadBoardWallpaper(data: data, coupleId: coupleId)
            try await supabase.updateBoardWallpaperUrl(coupleId: coupleId, url: url)
            wallpaperUrl = url
            if let channel {
                try await channel.broadcast(
                    event: BoardEvent.wallpaper,
                    message: WallpaperPayload(authorId: currentUserId, url: url)
                )
            }
        } catch {
            print("🚨 Failed to sync board wallpaper: \(error)")
            showToast(String(localized: "Couldn't update background. Try again."))
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
            signalStartIfNeeded()
        }
        pendingPoints.append(contentsOf: newPoints)
        scheduleFlush()
    }

    /// Notifies the partner (once per session) that this user has begun drawing.
    private func signalStartIfNeeded() {
        guard !didSignalStart else { return }
        didSignalStart = true
        Task { try? await supabase.markDrawingStarted() }
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

    /// Rasterizes the current board, pushes a centered-square composite to the partner widget,
    /// and saves a full-board snapshot to the shared archive.
    func sendToWidget(boardSize: CGSize) async {
        let strokes = committedStrokes + Array(remoteActiveStrokes.values)
        guard !strokes.isEmpty || wallpaper != nil else {
            showToast(String(localized: "Add a photo or draw something"))
            return
        }
        guard let widgetData = BoardSnapshotRenderer.widgetSquare(
            strokes: strokes,
            wallpaper: wallpaper,
            boardSize: boardSize
        ) else {
            showToast(String(localized: "Add a photo or draw something"))
            return
        }
        guard let coupleId else { return }

        do {
            let noteUrl = try await supabase.uploadNoteImage(data: widgetData)
            try await supabase.updateLatestNoteUrl(url: noteUrl)

            if let archiveData = BoardSnapshotRenderer.archiveJPEG(
                strokes: strokes,
                wallpaper: wallpaper,
                boardSize: boardSize
            ) {
                let archiveUrl = try await supabase.uploadArchiveImage(data: archiveData)
                try await supabase.insertArchivedDrawing(
                    coupleId: coupleId,
                    authorId: currentUserId,
                    imageUrl: archiveUrl
                )
            }

            showToast(String(localized: "Sent to \(partnerName)'s widget"))
        } catch {
            print("🚨 Failed to send drawing to widget: \(error)")
            showToast(String(localized: "Couldn't send. Try again."))
        }
    }

    /// True when the current user has at least one stroke to undo.
    var canUndo: Bool {
        committedStrokes.contains { $0.authorId == currentUserId }
    }

    /// True when there is anything on the board to send (strokes or a shared background).
    var canSend: Bool {
        !committedStrokes.isEmpty || !remoteActiveStrokes.isEmpty || wallpaper != nil
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

    private func handleWallpaper(_ json: JSONObject) {
        guard
            let payload = try? json["payload"]?.decode(as: WallpaperPayload.self),
            payload.authorId != currentUserId
        else { return }
        wallpaperUrl = payload.url
        Task {
            if let image = await downloadWallpaper(from: payload.url) {
                wallpaper = image
            }
        }
    }

    /// Downloads a wallpaper image from a public storage URL.
    private func downloadWallpaper(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data)
        else { return nil }
        return image
    }

    private func triggerToast() {
        showToast(String(localized: "\(partnerName) added to your board"))
    }

    /// Shows a transient banner and auto-dismisses it after a short delay.
    private func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
