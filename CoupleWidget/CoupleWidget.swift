import WidgetKit
import SwiftUI
import MapKit

// MARK: - Provider & Entry (Shared by both widgets)
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            distance: 1234.0,
            noteImage: nil,
            distanceUnit: "mi",
            myName: "Me",
            partnerName: "Partner",
            partnerMessage: "Love you always",
            anniversaryDate: Date(),
            myCoordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            partnerCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(
            date: Date(),
            distance: 1234.0,
            noteImage: nil,
            distanceUnit: "mi",
            myName: "Me",
            partnerName: "Partner",
            partnerMessage: "Love you always",
            anniversaryDate: Date(),
            myCoordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            partnerCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let defaults = UserDefaults(suiteName: "group.forever.widget")
            let distance = defaults?.double(forKey: "partnerDistance") ?? 0.0
            let distanceUnit = defaults?.string(forKey: "distanceUnit") ?? "mi"
            let myName = defaults?.string(forKey: "myName") ?? "Me"
            let partnerName = defaults?.string(forKey: "partnerName") ?? "P"
            let partnerMessage = defaults?.string(forKey: "partnerMessage")
            let anniversaryTimestamp = defaults?.object(forKey: "anniversaryDate") as? Double
            let anniversaryDate = anniversaryTimestamp.map { Date(timeIntervalSince1970: $0) }
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

            let entry = SimpleEntry(
                date: Date(),
                distance: distance,
                noteImage: downloadedImage,
                distanceUnit: distanceUnit,
                myName: myName,
                partnerName: partnerName,
                partnerMessage: partnerMessage,
                anniversaryDate: anniversaryDate,
                myCoordinate: myCoordinate,
                partnerCoordinate: partnerCoordinate
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
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let distance: Double
    let noteImage: UIImage?
    let distanceUnit: String
    let myName: String
    let partnerName: String
    let partnerMessage: String?
    let anniversaryDate: Date?
    let myCoordinate: CLLocationCoordinate2D?
    let partnerCoordinate: CLLocationCoordinate2D?
}

// Helper to calculate midpoint between coordinates.
extension CLLocationCoordinate2D {
    func midpoint(to other: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (latitude + other.latitude) / 2,
            longitude: (longitude + other.longitude) / 2
        )
    }
}

// MARK: - Widget 1: Distance Map View
struct DistanceWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            if let myCoord = entry.myCoordinate, let partnerCoord = entry.partnerCoordinate {
                Map(interactionModes: []) {
                    MapPolyline(coordinates: [myCoord, partnerCoord])
                        .stroke(Color.pink, style: StrokeStyle(lineWidth: 3, dash: [6, 6]))

                    Annotation("", coordinate: myCoord) {
                        WidgetMapAvatar()
                    }

                    Annotation("", coordinate: partnerCoord) {
                        WidgetMapAvatar()
                    }

                    Annotation("", coordinate: myCoord.midpoint(to: partnerCoord)) {
                        Text("\(Int(entry.distance)) \(entry.distanceUnit)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thickMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "location.slash.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Waiting for location...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct WidgetMapAvatar: View {
    var body: some View {
        ZStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(UIColor.systemGray3))
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
        .shadow(radius: 3)
    }
}

// MARK: - Widget 2: Drawing View (Notes)
struct DrawingWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            // Explicitly force a black background so white ink is always visible
            Color.black

            if let image = entry.noteImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(10)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "scribble.variable")
                        .font(.largeTitle)
                    Text("Waiting for note...")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
        // For iOS 17 container backgrounds
        .containerBackground(for: .widget) { Color.black }
    }
}

// MARK: - Widget 3: Lock Screen Message
struct LockScreenMessageWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let message = cleanedMessage {
                Text(cleanedName ?? "Partner")
                    .font(.caption2)
                    .lineLimit(1)
                Text(message)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
            } else {
                Text(cleanedName ?? "Partner")
                    .font(.caption2)
                    .lineLimit(1)
                Text("No message yet")
                    .font(.headline.weight(.bold))
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

    var myInitial: String { String(entry.myName.prefix(1)).uppercased() }
    var partnerInitial: String { String(entry.partnerName.prefix(1)).uppercased() }
    var isKilometers: Bool { entry.distanceUnit == "km" }
    var convertedDistance: Double { isKilometers ? entry.distance * 1.609344 : entry.distance }
    var distanceUnitLabel: String { isKilometers ? "km" : "mi" }

    var distanceText: String {
        entry.distance > 0 ? "\(Int(convertedDistance)) \(distanceUnitLabel)" : "-- \(distanceUnitLabel)"
    }

    // Calculate dynamic spacing based on distance.
    // 5000+ miles = max spacing. 0 miles = 0 spacing (touching the heart).
    var dynamicSpacing: CGFloat {
        guard entry.distance > 0 else { return 20 } // Default spacing if no data
        let maxDistance: Double = 5000.0 // The distance considered 'max separation'
        let maxSpacing: CGFloat = 25.0   // Max pixels of space between initial and heart
        let minSpacing: CGFloat = 2.0    // Min pixels of space (almost touching)

        // Map the distance to a percentage (0.0 to 1.0)
        let percentage = min(max(entry.distance / maxDistance, 0.0), 1.0)

        // Calculate the spacing
        let spacing = minSpacing + (maxSpacing - minSpacing) * CGFloat(percentage)
        return spacing
    }

    var body: some View {
        VStack(spacing: 6) {
            // Top Row: Distance Label and Value
            HStack(spacing: 4) {
                Text("DISTANCE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(distanceText)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }

            // Bottom Row: Initials dynamically moving closer to the heart
            HStack(spacing: dynamicSpacing) {
                ZStack {
                    Circle().stroke(lineWidth: 2.2)
                    Text(myInitial)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(width: 26, height: 26)

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

                ZStack {
                    Circle().stroke(lineWidth: 2.2)
                    Text(partnerInitial)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(width: 26, height: 26)
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
            family == .accessoryCircular ? Color.clear : Color.black
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
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private var systemSmallView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(UIColor.darkGray))
                    .frame(width: 54, height: 54)
                    
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(UIColor.darkGray))
                    .frame(width: 54, height: 54)
            }
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.pink)
                    .padding(5)
                    .background(Color.black)
                    .clipShape(Circle())
            }
            
            VStack(spacing: -2) {
                Text(dayText)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("DAYS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.gray)
                    .tracking(1.5)
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
        .configurationDisplayName("Distance Map")
        .description("See your distance with a live connection map.")
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
