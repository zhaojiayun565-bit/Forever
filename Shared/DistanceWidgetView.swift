import MapKit
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Timeline entry

struct SimpleEntry: TimelineEntry {
    var date: Date
    let distance: Double
    let noteImage: UIImage?
    let distanceUnit: String
    let myName: String
    let partnerName: String
    let myMessage: String?
    let partnerMessage: String?
    let myAvatarImage: UIImage?
    let partnerAvatarImage: UIImage?
    let anniversaryDate: Date?
    let myCoordinate: CLLocationCoordinate2D?
    let partnerCoordinate: CLLocationCoordinate2D?
    /// Pre-rendered map image produced by MKMapSnapshotter; nil when coordinates are unavailable.
    let mapSnapshot: UIImage?
    /// When the partner last reported their location (server time).
    var partnerLocationUpdatedAt: Date? = nil
}

extension SimpleEntry {
    var isKilometers: Bool { distanceUnit == "km" }

    var convertedDistance: Double {
        isKilometers ? distance * 1.609344 : distance
    }

    var distanceUnitLabel: String { isKilometers ? "km" : "mi" }

    /// True when both partners have coordinates and a distance can be shown.
    var hasDistanceData: Bool {
        myCoordinate != nil && partnerCoordinate != nil
    }

    /// Whether partners are effectively in the same place (rounds to 0 in the active unit).
    var isTogether: Bool {
        hasDistanceData && Int(convertedDistance.rounded()) == 0
    }

    /// Lock-screen distance value; -- when unavailable.
    var lockScreenDistanceText: String {
        guard hasDistanceData else { return "-- \(distanceUnitLabel)" }
        return "\(Int(convertedDistance)) \(distanceUnitLabel)"
    }

    static let togetherMessage = "We're together!"

    /// Distances newer than this are shown without an age label.
    static let freshLocationInterval: TimeInterval = 60 * 60

    /// Age of the partner's location at this entry's date, e.g. "3h ago"; nil while still fresh.
    var partnerLocationAge: String? {
        guard hasDistanceData, let updatedAt = partnerLocationUpdatedAt else { return nil }
        let age = date.timeIntervalSince(updatedAt)
        guard age >= Self.freshLocationInterval else { return nil }
        let hours = Int(age / 3600)
        return hours < 24 ? "\(hours)h ago" : "\(hours / 24)d ago"
    }

    /// Future dates at which `partnerLocationAge` changes, so a single reload keeps the label accurate.
    static func ageLabelChangeDates(after now: Date, updatedAt: Date?) -> [Date] {
        guard let updatedAt else { return [] }
        let hourly = (1..<24).map { updatedAt.addingTimeInterval(Double($0) * 3600) }
        let daily = (1...7).map { updatedAt.addingTimeInterval(Double($0) * 86_400) }
        return (hourly + daily).filter { $0 > now }
    }
}

// MARK: - Distance Widget Components

/// Find My-style monogram for the map distance widget (small + medium).
struct MonogramAvatar: View {
    let name: String
    var image: UIImage?
    var size: CGFloat = 44

    /// Find My-style gray fill (`systemGray`, #8E8E93 in light and dark).
    static let placeholderFill = Color(.systemGray)

    private var initial: String {
        ForeverMonogramBubble.initial(from: name)
    }

    var body: some View {
        ZStack {
            if image == nil {
                Circle()
                    .fill(MonogramAvatar.placeholderFill)
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }

            if image == nil {
                Text(initial)
                    .font(ForeverFont.bold(size: size * 0.3, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .foreverMonogramChrome(size: size, style: .glassDark)
    }
}

/// White capsule message bubble shown above each monogram on the medium widget.
struct MessageBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ForeverFont.bold(size: 12, relativeTo: .caption))
            .foregroundStyle(.black)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Distance Map View

/// Homescreen distance widget (small + medium). Shared by the widget extension and in-app previews.
struct DistanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SimpleEntry
    /// Overrides widget family when set (required for in-app previews; `widgetFamily` env is read-only in the app).
    var layoutFamily: WidgetFamily? = nil

    private var effectiveFamily: WidgetFamily {
        layoutFamily ?? family
    }

    private var isKilometers: Bool { entry.distanceUnit == "km" }
    private var convertedDistance: Double {
        isKilometers ? entry.distance * 1.609344 : entry.distance
    }
    private var distanceUnitLabel: String { isKilometers ? "km" : "mi" }

    private var distanceText: String {
        guard entry.distance > 0 else { return "-- \(distanceUnitLabel)" }
        return "\(Int(convertedDistance)) \(distanceUnitLabel)"
    }

    private var cleanedMyMessage: String? {
        let value = entry.myMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    private var cleanedPartnerMessage: String? {
        let value = entry.partnerMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    var body: some View {
        Group {
            if entry.mapSnapshot != nil {
                switch effectiveFamily {
                case .systemMedium:
                    mediumLayout
                default:
                    smallLayout
                }
            } else {
                emptyState
            }
        }
        .modifier(DistanceWidgetBackgroundModifier(mapSnapshot: entry.mapSnapshot))
    }

    private var distancePill: some View {
        Text(distanceText)
            .font(ForeverFont.bold(size: 14, relativeTo: .subheadline))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    /// "Updated 3h ago" under the distance once the partner's location is stale.
    @ViewBuilder
    private var freshnessLabel: some View {
        if let age = entry.partnerLocationAge {
            Text("Updated \(age)")
                .font(ForeverFont.bold(size: 11, relativeTo: .caption2))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
        }
    }

    private var smallLayout: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                MonogramAvatar(name: entry.myName, image: entry.myAvatarImage, size: 44)
                MonogramAvatar(name: entry.partnerName, image: entry.partnerAvatarImage, size: 44)
            }
            VStack(spacing: 4) {
                distancePill
                freshnessLabel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumLayout: some View {
        GeometryReader { geo in
            let anchorY = geo.size.height * 0.62
            let leftX: CGFloat = 52
            let rightX = geo.size.width - 52

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: leftX, y: anchorY))
                    path.addQuadCurve(
                        to: CGPoint(x: rightX, y: anchorY),
                        control: CGPoint(x: geo.size.width / 2, y: anchorY - 22)
                    )
                }
                .stroke(
                    Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5])
                )

                VStack(spacing: 4) {
                    distancePill
                    freshnessLabel
                }
                .position(x: geo.size.width / 2, y: anchorY + (entry.partnerLocationAge == nil ? 0 : 8))

                VStack(spacing: 6) {
                    if let message = cleanedMyMessage {
                        MessageBubble(text: message)
                    }
                    MonogramAvatar(name: entry.myName, image: entry.myAvatarImage, size: 50)
                }
                .position(x: leftX, y: anchorY - (cleanedMyMessage == nil ? 0 : 18))

                VStack(spacing: 6) {
                    if let message = cleanedPartnerMessage {
                        MessageBubble(text: message)
                    }
                    MonogramAvatar(name: entry.partnerName, image: entry.partnerAvatarImage, size: 50)
                }
                .position(x: rightX, y: anchorY - (cleanedPartnerMessage == nil ? 0 : 18))
            }
        }
    }

    private var emptyState: some View {
        let content = emptyStateContent
        return VStack(spacing: 8) {
            Image(systemName: content.icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(content.message)
                .font(ForeverFont.caption())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Chooses copy based on whether partner or own location is missing.
    private var emptyStateContent: (icon: String, message: String) {
        let hasPartner = !entry.partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && entry.partnerName != "P"

        if entry.partnerCoordinate == nil {
            if hasPartner {
                return ("person.crop.circle.badge.clock", "Waiting for partner...")
            }
            return ("heart.fill", "Pair with your partner in Forever")
        }

        if entry.myCoordinate == nil {
            return ("location.slash.fill", "Location permission is required for the widget to work!")
        }

        return ("map.fill", "Open Forever to refresh your map")
    }
}

// MARK: - Background

/// Uses widget container background in the extension; standard background in the main app.
private struct DistanceWidgetBackgroundModifier: ViewModifier {
    let mapSnapshot: UIImage?

    @ViewBuilder
    private var backgroundContent: some View {
        if let mapSnapshot {
            Image(uiImage: mapSnapshot)
                .resizable()
                .scaledToFill()
        } else {
            Color(.systemBackground)
        }
    }

    func body(content: Content) -> some View {
        if Bundle.main.bundleURL.pathExtension == "appex" {
            content.containerBackground(for: .widget) {
                backgroundContent
            }
        } else {
            content.background {
                backgroundContent
            }
        }
    }
}
