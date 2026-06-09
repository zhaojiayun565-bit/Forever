import CoreImage
import PhotosUI
import SwiftUI

// MARK: - Container

/// Full-screen shared drawing board styled as an iOS Lock Screen.
struct LockscreenDrawingBoardView: View {
    @Environment(AppStateManager.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var board: DrawingBoardManager?
    @State private var penColor: Color = .white
    @State private var photoItem: PhotosPickerItem?
    @State private var boardSize: CGSize = .zero

    private let penWidth: Double = 6

    var body: some View {
        ZStack {
            if let board {
                BoardBackgroundView(wallpaper: board.wallpaper)
                DrawingCanvasView(board: board, penColor: $penColor, penWidth: penWidth, boardSize: $boardSize)

                VStack(spacing: 8) {
                    LockscreenClockView()
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)

                BoardToastOverlay(board: board)
            } else {
                ProgressView()
                    .tint(.primary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let board {
                FloatingDrawingToolbar(
                    penColor: $penColor,
                    photoItem: $photoItem,
                    canUndo: board.canUndo,
                    canSend: board.canSend,
                    onClose: { dismiss() },
                    onUndo: { Task { await board.undoLast() } },
                    onClear: { Task { await board.clearAll() } },
                    onSend: { Task { await board.sendToWidget(boardSize: boardSize) } }
                )
                .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(usesDarkChrome ? .dark : .light)
        .task {
            let manager = DrawingBoardManager(
                coupleId: appState.currentCouple?.id,
                currentUserId: appState.currentUser?.id ?? UUID(),
                partnerName: appState.partnerDisplayName
            )
            board = manager
            await manager.start()
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem, let board else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await board.setWallpaper(image)
                }
            }
        }
        .onDisappear {
            if let board { Task { await board.stop() } }
        }
    }

    /// Picks a dark or light scheme from the wallpaper's top strip (default gradient is dark).
    private var usesDarkChrome: Bool {
        board?.wallpaper.map { !$0.topRegionIsLight() } ?? true
    }
}

// MARK: - Background

private struct BoardBackgroundView: View {
    let wallpaper: UIImage?

    var body: some View {
        Group {
            if let wallpaper {
                Image(uiImage: wallpaper)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.10, blue: 0.18), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Canvas

/// Isolates the high-frequency drawing state: the in-progress local stroke lives in this
/// view's `@State`, so dragging never re-renders the clock or toolbar.
private struct DrawingCanvasView: View {
    let board: DrawingBoardManager
    @Binding var penColor: Color
    let penWidth: Double
    /// Reports the full-screen canvas size used to normalize strokes, so the widget crop matches.
    @Binding var boardSize: CGSize

    @State private var currentStroke: DrawStroke?

    var body: some View {
        // Reading these in `body` registers observation so the Canvas redraws on remote updates.
        let committed = board.committedStrokes
        let remote = Array(board.remoteActiveStrokes.values)
        let inProgress = currentStroke

        GeometryReader { geo in
            let canvasWidth = geo.size.width
            Canvas { context, size in
                let scale = size.width
                for stroke in committed { Self.draw(stroke, in: &context, scale: scale) }
                for stroke in remote { Self.draw(stroke, in: &context, scale: scale) }
                if let inProgress { Self.draw(inProgress, in: &context, scale: scale) }
            }
            .contentShape(Rectangle())
            .gesture(drawGesture(canvasWidth: canvasWidth))
            .onAppear { boardSize = geo.size }
            .onChange(of: geo.size) { _, newSize in boardSize = newSize }
        }
        .ignoresSafeArea()
    }

    private func drawGesture(canvasWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canvasWidth > 0 else { return }
                // Width-normalized so geometry survives differing screen aspect ratios.
                let point = CGPoint(x: value.location.x / canvasWidth, y: value.location.y / canvasWidth)
                if currentStroke == nil {
                    currentStroke = DrawStroke(
                        id: UUID(),
                        authorId: board.currentUserId,
                        colorHex: penColor.toHexString(),
                        width: penWidth / Double(canvasWidth),
                        points: [point]
                    )
                } else {
                    currentStroke?.points.append(point)
                }
                if let stroke = currentStroke {
                    board.enqueueLocalPoints(
                        strokeId: stroke.id,
                        colorHex: stroke.colorHex,
                        width: stroke.width,
                        newPoints: [point]
                    )
                }
            }
            .onEnded { _ in
                guard let stroke = currentStroke else { return }
                currentStroke = nil
                Task { await board.commitLocalStroke(stroke) }
            }
    }

    /// Renders a stroke, scaling normalized coordinates by canvas width (uniform on both axes).
    private static func draw(_ stroke: DrawStroke, in context: inout GraphicsContext, scale: CGFloat) {
        let points = stroke.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        let lineWidth = max(1, stroke.width * scale)
        let color = Color(hexString: stroke.colorHex)

        guard points.count > 1 else {
            // A single tap renders as a dot.
            if let dot = points.first {
                let r = lineWidth / 2
                let rect = CGRect(x: dot.x - r, y: dot.y - r, width: lineWidth, height: lineWidth)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
            return
        }

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Lock Screen chrome

/// Centered time + date using native typography. Strictly flat: no shadows, no widgets.
private struct LockscreenClockView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            VStack(spacing: 4) {
                Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(ForeverFont.subheader(size: 21, relativeTo: .headline))
                Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(ForeverFont.header(size: 88, relativeTo: .largeTitle))
            }
            .foregroundStyle(.primary)
        }
    }
}

// MARK: - Floating toolbar

private struct FloatingDrawingToolbar: View {
    @Binding var penColor: Color
    @Binding var photoItem: PhotosPickerItem?
    let canUndo: Bool
    let canSend: Bool
    let onClose: () -> Void
    let onUndo: () -> Void
    let onClear: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            ToolbarIconButton(systemName: "xmark", action: onClose)

            ColorPicker("Pen color", selection: $penColor, supportsOpacity: false)
                .labelsHidden()

            ToolbarIconButton(systemName: "arrow.uturn.backward", action: onUndo)
                .disabled(!canUndo)
                .opacity(canUndo ? 1 : 0.35)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .toolbarIconStyle()
            }

            ToolbarIconButton(systemName: "trash", role: .destructive, action: onClear)

            SendToWidgetButton(isEnabled: canSend, action: onSend)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

/// Sends the board to the partner's widget. Mirrors the lock-screen message send icon:
/// a white paperplane in a filled pink circle, dimmed gray when there's nothing to send.
private struct SendToWidgetButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(isEnabled ? Color.pink : Color.gray.opacity(0.4), in: Circle())
        }
        .buttonStyle(BubblyButtonStyle())
        .disabled(!isEnabled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEnabled)
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .toolbarIconStyle(tint: role == .destructive ? .red : .primary)
        }
        .buttonStyle(BubblyButtonStyle())
    }
}

private extension Image {
    func toolbarIconStyle(tint: Color = .primary) -> some View {
        self
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
    }
}

// MARK: - In-app toast

/// Separate observer so the toast never re-renders the canvas container.
private struct BoardToastOverlay: View {
    let board: DrawingBoardManager

    var body: some View {
        VStack {
            if let message = board.toastMessage {
                Label(message, systemImage: "scribble.variable")
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: board.toastMessage)
    }
}

// MARK: - Brightness sampling

private extension UIImage {
    /// Average brightness of the top strip (where the status bar sits). > 0.6 is "light".
    func topRegionIsLight(fraction: CGFloat = 0.12) -> Bool {
        guard let cg = cgImage else { return false }
        let ci = CIImage(cgImage: cg)
        let stripHeight = ci.extent.height * fraction
        // CoreImage origin is bottom-left, so the top strip is at maxY - stripHeight.
        let rect = CGRect(x: ci.extent.minX, y: ci.extent.maxY - stripHeight,
                          width: ci.extent.width, height: stripHeight)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ci, kCIInputExtentKey: CIVector(cgRect: rect)
        ]), let output = filter.outputImage else { return false }
        var px = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &px, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: nil)
        let luminance = 0.299 * Double(px[0]) + 0.587 * Double(px[1]) + 0.114 * Double(px[2])
        return luminance / 255 > 0.6
    }
}

