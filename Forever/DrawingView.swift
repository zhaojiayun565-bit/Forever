import SwiftUI
import PencilKit

struct DrawingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var canvasView = PKCanvasView()
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Canvas is the back layer — solid black so white ink is always visible.
            DrawingCanvas(canvasView: $canvasView) { data in
                Task { await SupabaseManager.shared.broadcastDrawing(data: data) }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LockScreenHeader()
                    .padding(.top, 60)
                Spacer()
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()
                HStack(spacing: 24) {
                    Button {
                        canvasView.drawing = PKDrawing()
                    } label: {
                        Image(systemName: "trash").font(.title2).foregroundColor(.white)
                    }.disabled(isSending)

                    Button {
                        canvasView.undoManager?.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward").font(.title2).foregroundColor(.white)
                    }.disabled(isSending)

                    Button {
                        Task { await sendNote() }
                    } label: {
                        HStack {
                            Text(isSending ? "Sending..." : "Send")
                                .fontWeight(.bold)
                            if !isSending { Image(systemName: "paperplane.fill") }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }.disabled(isSending)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
                .padding(.bottom, 40)
            }

            if isSending {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView().scaleEffect(1.5).tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let couple = try? await SupabaseManager.shared.fetchCurrentCouple() {
                await SupabaseManager.shared.joinDrawingChannel(coupleId: couple.id) { incomingData in
                    applyPartnerDrawing(data: incomingData)
                }
            }
        }
        .onDisappear {
            Task { await SupabaseManager.shared.leaveDrawingChannel() }
        }
    }

    /// Applies incoming partner drawing by temporarily detaching the delegate to prevent echo broadcast.
    @MainActor
    private func applyPartnerDrawing(data: Data) {
        guard let partnerDrawing = try? PKDrawing(data: data) else { return }
        let currentDelegate = canvasView.delegate
        canvasView.delegate = nil
        canvasView.drawing = partnerDrawing
        canvasView.delegate = currentDelegate
    }

    private func sendNote() async {
        isSending = true
        defer { isSending = false }

        let size = canvasView.bounds.size
        let rect = size == .zero ? UIScreen.main.bounds : CGRect(origin: .zero, size: size)

        let image = canvasView.drawing.image(from: rect, scale: 2.0)
        guard let data = image.pngData() else { return }

        do {
            let url = try await SupabaseManager.shared.uploadNoteImage(data: data)
            try await SupabaseManager.shared.updateLatestNoteUrl(url: url)
            canvasView.drawing = PKDrawing()
            dismiss()
        } catch {
            print("🚨 Failed to upload note: \(error)")
        }
    }
}

struct LockScreenHeader: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            VStack(spacing: 4) {
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Canvas Representable

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var onDrawingChanged: (Data) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .black
        canvasView.isOpaque = true
        canvasView.tool = PKInkingTool(.pen, color: .white, width: 5)
        canvasView.bouncesZoom = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Intentionally empty — all mutations go directly through canvasView.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        private var lastBroadcastTime: Date = .distantPast
        private let throttleInterval: TimeInterval = 0.2 // max 5 broadcasts/second

        init(_ parent: DrawingCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let now = Date()
            guard now.timeIntervalSince(lastBroadcastTime) > throttleInterval else { return }
            lastBroadcastTime = now
            parent.onDrawingChanged(canvasView.drawing.dataRepresentation())
        }
    }
}
