import SwiftUI
import PencilKit

struct DrawingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var canvasView = PKCanvasView()
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // The Canvas
                CanvasRepresentable(canvasView: $canvasView)
                    .edgesIgnoringSafeArea(.all)

                if isSending {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Sending to partner...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Draw a Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        canvasView.drawing = PKDrawing()
                    }
                    .disabled(isSending)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        Task { await sendNote() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending)
                }
            }
        }
    }

    private func sendNote() async {
        isSending = true
        defer { isSending = false }

        // Extract the drawing with a white background so it shows up cleanly on the widget
        let trait = UITraitCollection(userInterfaceStyle: .light)
        canvasView.backgroundColor = .white
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
        canvasView.backgroundColor = .clear // reset

        guard let data = image.pngData() else { return }

        do {
            let url = try await SupabaseManager.shared.uploadNoteImage(data: data)
            try await SupabaseManager.shared.updateLatestNoteUrl(url: url)

            // Force widget reload on my side too (optional, but good for sync)
            canvasView.drawing = PKDrawing()
            dismiss()
        } catch {
            print("🚨 Failed to upload note: \(error)")
        }
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 6)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
