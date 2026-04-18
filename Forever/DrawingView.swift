import SwiftUI
import PencilKit

struct DrawingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var canvasView = PKCanvasView()
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 1. The Canvas is now the BACK layer, and it is purely BLACK and OPAQUE.
            // This forces the physical iPhone GPU to perfectly render the white ink.
            CanvasRepresentable(canvasView: $canvasView)
                .ignoresSafeArea()

            // 2. The Clock is moved ON TOP of the canvas so we can see it.
            VStack(spacing: 0) {
                LockScreenHeader()
                    .padding(.top, 60)
                Spacer()
            }
            // CRITICAL: Let touches pass right through the clock down to the canvas
            .allowsHitTesting(false)

            // 3. The Toolbar stays on top and clickable
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
    }

    private func sendNote() async {
        isSending = true
        defer { isSending = false }

        // This seamlessly extracts the strokes on a transparent background, ignoring the solid black canvas!
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
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

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        // THE FIX: Solid black and opaque guarantees rendering on physical devices
        canvasView.backgroundColor = .black
        canvasView.isOpaque = true

        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .white, width: 5)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Re-enforce tool and policy in case of SwiftUI re-renders
        uiView.drawingPolicy = .anyInput
        uiView.tool = PKInkingTool(.pen, color: .white, width: 5)
    }
}
