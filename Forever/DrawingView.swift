import SwiftUI
import PencilKit

struct DrawingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var drawing = PKDrawing()
    @State private var isSending = false
    @State private var canvasSize: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Canvas is the back layer — solid black so white ink is always visible.
            CanvasRepresentable(drawing: $drawing, canvasSize: $canvasSize)
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
                        drawing = PKDrawing()
                    } label: {
                        Image(systemName: "trash").font(.title2).foregroundColor(.white)
                    }.disabled(isSending)

                    Button {
                        // Undo is managed by the canvas's own UndoManager internally.
                        // Clearing the binding triggers updateUIView which assigns a fresh drawing;
                        // true undo requires the canvas to handle it. We post the undo action.
                        NotificationCenter.default.post(name: .drawingUndo, object: nil)
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
    }

    private func sendNote() async {
        isSending = true
        defer { isSending = false }

        // Use the captured canvas size; fall back to the main screen bounds.
        let rect = canvasSize == .zero
            ? UIScreen.main.bounds
            : CGRect(origin: .zero, size: canvasSize)

        let image = drawing.image(from: rect, scale: 2.0)
        guard let data = image.pngData() else { return }

        do {
            let url = try await SupabaseManager.shared.uploadNoteImage(data: data)
            try await SupabaseManager.shared.updateLatestNoteUrl(url: url)
            drawing = PKDrawing()
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

// MARK: - Notification for undo

extension Notification.Name {
    static let drawingUndo = Notification.Name("drawingUndo")
}

// MARK: - Canvas Representable

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var canvasSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, canvasSize: $canvasSize)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .black
        canvas.isOpaque = true
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .white, width: 5)
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 1. Prevent the infinite layout loop by checking if the size actually changed
        if uiView.bounds.size != .zero && canvasSize != uiView.bounds.size {
            DispatchQueue.main.async {
                canvasSize = uiView.bounds.size
            }
        }

        // 2. Prevent touch gesture cancellation
        // Only push drawing changes to the canvas if the SwiftUI state is fundamentally
        // cleared (e.g., via the Trash button). NEVER update during a live stroke.
        if drawing.strokes.isEmpty && !uiView.drawing.strokes.isEmpty {
            uiView.drawing = drawing
        }
    }
}

// MARK: - Coordinator

final class Coordinator: NSObject, PKCanvasViewDelegate {
    private var drawingBinding: Binding<PKDrawing>
    private var canvasSizeBinding: Binding<CGSize>
    weak var canvas: PKCanvasView?
    private var undoObserver: Any?

    init(drawing: Binding<PKDrawing>, canvasSize: Binding<CGSize>) {
        self.drawingBinding = drawing
        self.canvasSizeBinding = canvasSize
        super.init()
        undoObserver = NotificationCenter.default.addObserver(
            forName: .drawingUndo,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.canvas?.undoManager?.undo()
        }
    }

    deinit {
        if let observer = undoObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Sync the completed drawing back to SwiftUI after each stroke.
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        drawingBinding.wrappedValue = canvasView.drawing
    }
}
