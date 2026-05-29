import SwiftUI

// MARK: - Stroke Model

/// A single pen stroke on the shared board.
///
/// Coordinates are **width-normalized**: both x and y are divided by the author's
/// canvas width (a single uniform scale factor), so shapes keep their true geometry
/// across devices with different aspect ratios. `width` is likewise stored as a
/// fraction of canvas width so stroke thickness stays visually proportional.
struct DrawStroke: Identifiable, Equatable, Sendable {
    let id: UUID
    let authorId: UUID
    var colorHex: String
    var width: Double
    var points: [CGPoint]
}

// MARK: - Realtime Broadcast Payloads

/// Lightweight incremental broadcast payload. Carries only the NEW points since the
/// last chunk to keep WebSocket messages tiny. Points are flattened `[x0, y0, x1, y1, ...]`.
struct StrokeChunkPayload: Codable, Sendable {
    let strokeId: UUID
    let authorId: UUID
    let colorHex: String
    let width: Double
    let points: [Double]
    let isFinal: Bool
}

/// Payload for `undo` / `clear` control events.
struct BoardControlPayload: Codable, Sendable {
    let authorId: UUID
    /// The stroke to remove for `undo`; `nil` for `clear`.
    let strokeId: UUID?
}

/// Broadcast event names used on the drawing-board channel.
enum BoardEvent {
    static let stroke = "stroke"
    static let undo = "undo"
    static let clear = "clear"
}

// MARK: - Supabase DTOs

/// Insert payload for the `drawing_strokes` table.
struct DrawingStrokeInsert: Encodable, Sendable {
    let id: UUID
    let couple_id: UUID
    let author_id: UUID
    let color_hex: String
    let width: Double
    let points: [Double]
}

/// Row decoded from the `drawing_strokes` table.
struct DrawingStrokeRow: Decodable, Sendable {
    let id: UUID
    let author_id: UUID
    let color_hex: String
    let width: Double
    let points: [Double]

    func toDrawStroke() -> DrawStroke {
        DrawStroke(
            id: id,
            authorId: author_id,
            colorHex: color_hex,
            width: width,
            points: points.toCGPoints()
        )
    }
}

// MARK: - Point Packing Helpers

extension Array where Element == CGPoint {
    /// Flattens points into `[x0, y0, x1, y1, ...]` for compact transport/storage.
    var flattened: [Double] {
        flatMap { [Double($0.x), Double($0.y)] }
    }
}

extension Array where Element == Double {
    /// Rebuilds `[CGPoint]` from a flattened `[x0, y0, x1, y1, ...]` array.
    func toCGPoints() -> [CGPoint] {
        guard count >= 2 else { return [] }
        return stride(from: 0, to: count - 1, by: 2).map {
            CGPoint(x: self[$0], y: self[$0 + 1])
        }
    }
}

// MARK: - Color <-> Hex

extension Color {
    /// Builds a color from a `#RRGGBB` hex string (falls back to white on parse failure).
    init(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value), hex.count == 6 else {
            self = .white
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    /// Serializes to an opaque `#RRGGBB` hex string.
    func toHexString() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255))
        )
    }
}
