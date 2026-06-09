import WidgetKit
import SwiftUI
import MapKit

// MARK: - Provider & Entry (Shared by both widgets)
struct Provider: TimelineProvider {
    private static let appGroupSuiteName = "group.com.jiayunzhao.Forever"

    private static let fallbackPreviewAnniversaryDate = Calendar.current.date(
        byAdding: .day, value: -825, to: Date()
    ) ?? Date()

    /// Reads anniversary from App Group, falling back to a sample date for widget gallery previews.
    private static func previewAnniversaryDate(from defaults: UserDefaults?) -> Date {
        anniversaryDate(from: defaults) ?? fallbackPreviewAnniversaryDate
    }

    private static func anniversaryDate(from defaults: UserDefaults?) -> Date? {
        guard let timestamp = defaults?.object(forKey: "anniversaryDate") as? Double else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func placeholder(in context: Context) -> SimpleEntry {
        let defaults = UserDefaults(suiteName: Self.appGroupSuiteName)
        return SimpleEntry(
            date: Date(),
            distance: 1234.0,
            noteImage: nil,
            distanceUnit: "mi",
            myName: "Me",
            partnerName: "Partner",
            myMessage: "I miss you",
            partnerMessage: "Thinking of you",
            myAvatarImage: nil,
            partnerAvatarImage: nil,
            anniversaryDate: Self.previewAnniversaryDate(from: defaults),
            myCoordinate: nil,
            partnerCoordinate: nil,
            mapSnapshot: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let defaults = UserDefaults(suiteName: Self.appGroupSuiteName)
        let myCoord = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
        let partnerCoord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        Task {
            let snapshot = try? await Self.makeMapSnapshot(
                myCoord: myCoord,
                partnerCoord: partnerCoord,
                size: context.displaySize
            )
            completion(SimpleEntry(
                date: Date(),
                distance: 1234.0,
                noteImage: nil,
                distanceUnit: "mi",
                myName: "Me",
                partnerName: "Partner",
                myMessage: "I miss you",
                partnerMessage: "Thinking of you",
                myAvatarImage: nil,
                partnerAvatarImage: nil,
                anniversaryDate: Self.previewAnniversaryDate(from: defaults),
                myCoordinate: myCoord,
                partnerCoordinate: partnerCoord,
                mapSnapshot: snapshot
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let defaults = UserDefaults(suiteName: Self.appGroupSuiteName)
            let distance = defaults?.double(forKey: "partnerDistance") ?? 0.0
            let distanceUnit = defaults?.string(forKey: "distanceUnit") ?? "mi"
            let myName = defaults?.string(forKey: "myName") ?? "Me"
            let partnerName = defaults?.string(forKey: "partnerName") ?? "P"
            let myMessage = defaults?.string(forKey: "myMessage")
            let partnerMessage = defaults?.string(forKey: "partnerMessage")
            let anniversaryDate = Self.anniversaryDate(from: defaults)
            let myCoordinate = Self.coordinateFromAmbientData(
                defaults: defaults,
                explicitLatKey: "myLatitude",
                explicitLonKey: "myLongitude",
                jsonKeys: ["myAmbientData", "currentUserAmbientData", "currentUser", "myProfile"]
            )
            let partnerCoordinate = Self.coordinateFromAmbientData(
                defaults: defaults,
                explicitLatKey: "partnerLatitude",
                explicitLonKey: "partnerLongitude",
                jsonKeys: ["partnerAmbientData", "partnerProfileAmbientData", "partnerProfile"]
            )

            var downloadedImage: UIImage? = nil
            if let urlString = defaults?.string(forKey: "partnerNoteUrl"),
               let url = URL(string: urlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    downloadedImage = UIImage(data: data)
                } catch {
                    print("🚨 Widget Image Download Failed: \(error)")
                }
            }

            var mapSnapshot: UIImage? = nil
            if let myCoord = myCoordinate, let partnerCoord = partnerCoordinate {
                mapSnapshot = try? await Self.makeMapSnapshot(
                    myCoord: myCoord,
                    partnerCoord: partnerCoord,
                    size: context.displaySize
                )
            }

            async let myAvatar = Self.loadAvatarImage(
                defaults: defaults,
                fileName: "my-avatar.jpg",
                urlKey: "myAvatarUrl"
            )
            async let partnerAvatar = Self.loadAvatarImage(
                defaults: defaults,
                fileName: "partner-avatar.jpg",
                urlKey: "partnerAvatarUrl"
            )

            let entry = SimpleEntry(
                date: Date(),
                distance: distance,
                noteImage: downloadedImage,
                distanceUnit: distanceUnit,
                myName: myName,
                partnerName: partnerName,
                myMessage: myMessage,
                partnerMessage: partnerMessage,
                myAvatarImage: await myAvatar,
                partnerAvatarImage: await partnerAvatar,
                anniversaryDate: anniversaryDate,
                myCoordinate: myCoordinate,
                partnerCoordinate: partnerCoordinate,
                mapSnapshot: mapSnapshot
            )
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }

    /// Reads a coordinate from app-group defaults using explicit keys first, then ambient JSON payloads.
    private static func coordinateFromAmbientData(
        defaults: UserDefaults?,
        explicitLatKey: String,
        explicitLonKey: String,
        jsonKeys: [String]
    ) -> CLLocationCoordinate2D? {
        guard let defaults else { return nil }

        if let coordinate = coordinateFromExplicitKeys(defaults: defaults, latKey: explicitLatKey, lonKey: explicitLonKey) {
            return coordinate
        }

        for key in jsonKeys {
            if let coordinate = coordinateFromJSONString(defaults: defaults, key: key) {
                return coordinate
            }
        }
        return nil
    }

    private static func coordinateFromExplicitKeys(
        defaults: UserDefaults,
        latKey: String,
        lonKey: String
    ) -> CLLocationCoordinate2D? {
        guard
            let lat = defaults.object(forKey: latKey) as? Double,
            let lon = defaults.object(forKey: lonKey) as? Double
        else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private static func coordinateFromJSONString(defaults: UserDefaults, key: String) -> CLLocationCoordinate2D? {
        guard let json = defaults.string(forKey: key), let data = json.data(using: .utf8) else {
            return nil
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return coordinateFromJSONObject(object)
    }

    private static func coordinateFromJSONObject(_ object: Any) -> CLLocationCoordinate2D? {
        if let dictionary = object as? [String: Any] {
            if
                let latitude = dictionary["latitude"] as? Double,
                let longitude = dictionary["longitude"] as? Double
            {
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            if
                let lat = dictionary["lat"] as? Double,
                let lon = dictionary["lon"] as? Double
            {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return nil
    }

    /// Renders a static edge-to-edge map image using MKMapSnapshotter (widget-safe).
    static func makeMapSnapshot(
        myCoord: CLLocationCoordinate2D,
        partnerCoord: CLLocationCoordinate2D,
        size: CGSize
    ) async throws -> UIImage {
        let midpoint = CLLocationCoordinate2D(
            latitude: (myCoord.latitude + partnerCoord.latitude) / 2,
            longitude: (myCoord.longitude + partnerCoord.longitude) / 2
        )
        let latDelta = abs(myCoord.latitude - partnerCoord.latitude)
        let lonDelta = abs(myCoord.longitude - partnerCoord.longitude)
        let minSpan = 0.02
        let padding = 1.7

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: midpoint,
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta * padding, minSpan),
                longitudeDelta: max(lonDelta * padding, minSpan)
            )
        )
        options.size = size
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MKMapSnapshotter.Snapshot, Error>) in
            snapshotter.start { result, error in
                if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: error ?? URLError(.unknown))
                }
            }
        }

        return snapshot.image
    }

    /// Loads an avatar from the App Group cache, falling back to a remote URL.
    private static func loadAvatarImage(
        defaults: UserDefaults?,
        fileName: String,
        urlKey: String
    ) async -> UIImage? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jiayunzhao.Forever") {
            let fileURL = container.appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                return image
            }
        }

        if let urlString = defaults?.string(forKey: urlKey),
           let url = URL(string: urlString),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }
}

// MARK: - Widget 2: Drawing View (Notes)
struct DrawingWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            if entry.noteImage == nil {
                VStack(spacing: 8) {
                    Image(systemName: "scribble.variable")
                        .font(.largeTitle)
                    Text("Waiting for note...")
                        .font(ForeverFont.caption())
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        // Tapping the note widget opens the shared drawing board.
        .widgetURL(URL(string: "forever://drawingboard"))
        // The composite is a pre-flattened square (background + strokes); fill the widget edge-to-edge.
        .containerBackground(for: .widget) {
            if let image = entry.noteImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black
            }
        }
    }
}

// MARK: - Widget 3: Lock Screen Message
struct LockScreenMessageWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let message = cleanedMessage {
                Text(cleanedName ?? "Partner")
                    .font(ForeverFont.caption(.caption2))
                    .lineLimit(1)
                Text(message)
                    .font(ForeverFont.bold(.headline))
                    .lineLimit(2)
            } else {
                Text(cleanedName ?? "Partner")
                    .font(ForeverFont.caption(.caption2))
                    .lineLimit(1)
                Text("No message yet")
                    .font(ForeverFont.bold(.headline))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var cleanedName: String? {
        let value = entry.partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var cleanedMessage: String? {
        let value = entry.partnerMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }
}

struct DistanceLockScreenWidgetView: View {
    var entry: Provider.Entry

    var distanceText: String { entry.lockScreenDistanceText }

    // Calculate dynamic spacing based on distance.
    // 5000+ miles = max spacing. 0 miles = min spacing (touching the heart).
    var dynamicSpacing: CGFloat {
        guard entry.hasDistanceData else { return 20 }
        if entry.isTogether { return 2.0 }

        let maxDistance: Double = 5000.0
        let maxSpacing: CGFloat = 25.0
        let minSpacing: CGFloat = 2.0
        let percentage = min(max(entry.distance / maxDistance, 0.0), 1.0)
        return minSpacing + (maxSpacing - minSpacing) * CGFloat(percentage)
    }

    var body: some View {
        VStack(spacing: 6) {
            if entry.isTogether {
                Text(SimpleEntry.togetherMessage)
                    .font(ForeverFont.header(size: 12, relativeTo: .caption))
            } else {
                HStack(spacing: 4) {
                    Text("DISTANCE")
                        .font(ForeverFont.bold(size: 10, relativeTo: .caption2))
                        .foregroundStyle(.secondary)
                    Text(distanceText)
                        .font(ForeverFont.header(size: 12, relativeTo: .caption))
                }
            }

            // Bottom Row: Initials dynamically moving closer to the heart
            HStack(spacing: dynamicSpacing) {
                ForeverMonogramBubble(
                    name: entry.myName,
                    size: 26,
                    style: .glassDark
                )

                // Dashed line and Heart
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: dynamicSpacing > 5 ? dynamicSpacing - 5 : 0, height: 1)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: dynamicSpacing > 5 ? dynamicSpacing - 5 : 0, height: 1)
                }

                ForeverMonogramBubble(
                    name: entry.partnerName,
                    size: 26,
                    style: .glassDark
                )
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget 4: Days Together
struct DaysTogetherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                accessoryCircularView
            default:
                systemSmallView
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular {
                Color.clear
            } else {
                ZStack {
                    Color.black.opacity(0.32)
                    Color(red: 0.16, green: 0.13, blue: 0.18).opacity(0.58)
                }
            }
        }
    }

    private var daysTogether: Int? {
        guard let anniversary = entry.anniversaryDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: anniversary)
        let end = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    private var dayText: String {
        if let daysTogether {
            return "\(daysTogether)"
        }
        return "--"
    }

    private var accessoryCircularView: some View {
        ZStack {
            Circle().fill(Color.clear)
            VStack(spacing: 0) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Text(dayText)
                    .font(ForeverFont.header(size: 18, relativeTo: .headline))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private var systemSmallView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ForeverMonogramBubble(
                    name: entry.myName,
                    image: entry.myAvatarImage,
                    size: 54,
                    style: .glassDark
                )

                ForeverMonogramBubble(
                    name: entry.partnerName,
                    image: entry.partnerAvatarImage,
                    size: 54,
                    style: .glassDark
                )
            }
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: -2) {
                Text(dayText)
                    .font(ForeverFont.header(size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(.white)

                Text("Days Together")
                    .font(ForeverFont.subheader(size: 13, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Configurations
struct StatusWidget: Widget {
    let kind: String = "StatusWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DistanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("Location permission is required for the widget to work!")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DrawingWidget: Widget {
    let kind: String = "DrawingWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DrawingWidgetView(entry: entry)
        }
        .configurationDisplayName("Partner Note")
        .description("See the latest drawing from your partner.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct LockScreenMessageWidget: Widget {
    let kind: String = "LockScreenMessageWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenMessageWidgetView(entry: entry)
        }
        .configurationDisplayName("Partner Message")
        .description("Shows your partner's latest lock screen message.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct DistanceLockScreenWidget: Widget {
    let kind: String = "DistanceLockScreenWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DistanceLockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Connected Distance")
        .description("See how far away you are from each other.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct DaysTogetherWidget: Widget {
    let kind: String = "DaysTogetherWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DaysTogetherWidgetView(entry: entry)
        }
        .configurationDisplayName("Days Together")
        .description("Tracks days since your anniversary date.")
        .supportedFamilies([.accessoryCircular, .systemSmall])
    }
}

// MARK: - The Widget Bundle (Registers both widgets)
@main
struct ForeverWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        DrawingWidget()
        LockScreenMessageWidget()
        DistanceLockScreenWidget()
        DaysTogetherWidget()
    }
}
