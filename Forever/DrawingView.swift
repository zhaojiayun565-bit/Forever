import SwiftUI
import PencilKit

struct DrawingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var canvasView = PKCanvasView()
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 1. The Fake Lock Screen Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 2. The Lock Screen Header (Real-time Clock & Date)
                LockScreenHeader()
                    .padding(.top, 60)

                Spacer()
            }

            // 3. The Transparent Drawing Canvas
            CanvasRepresentable(canvasView: $canvasView)
                .edgesIgnoringSafeArea(.all)

            // 4. The Custom Blurred Toolbar
            VStack {
                Spacer()

                HStack(spacing: 24) {
                    Button {
                        canvasView.drawing = PKDrawing()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(isSending)

                    Button {
                        canvasView.undoManager?.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(isSending)

                    Button {
                        Task { await sendNote() }
                    } label: {
                        HStack {
                            Text(isSending ? "Sending..." : "Send")
                                .fontWeight(.bold)
                            if !isSending {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    }
                    .disabled(isSending)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark) // Forces the material to be dark
                .padding(.bottom, 40)
            }

            // 5. Sending Overlay
            if isSending {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar) // Hide default navigation bar for full immersion
    }

    private func sendNote() async {
        isSending = true
        defer { isSending = false }

        // Export with transparent background for Lock Screen widget template mask
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

                // To mimic the exact iOS lock screen clock font
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
        canvasView.drawingPolicy = .anyInput
        // Default to white ink so it pops against the black background
        canvasView.tool = PKInkingTool(.pen, color: .white, width: 6)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
