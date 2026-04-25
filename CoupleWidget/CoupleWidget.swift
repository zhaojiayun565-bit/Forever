import WidgetKit
import SwiftUI

// MARK: - Provider & Entry (Shared by both widgets)
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            distance: 1234.0,
            batteryLevel: 85,
            noteImage: nil,
            distanceUnit: "mi",
            myName: "Me",
            partnerName: "Partner",
            partnerMessage: "Love you always",
            anniversaryDate: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(
            date: Date(),
            distance: 1234.0,
            batteryLevel: 85,
            noteImage: nil,
            distanceUnit: "mi",
            myName: "Me",
            partnerName: "Partner",
            partnerMessage: "Love you always",
            anniversaryDate: Date()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let defaults = UserDefaults(suiteName: "group.forever.widget")
            let distance = defaults?.double(forKey: "partnerDistance") ?? 0.0
            let battery = defaults?.integer(forKey: "partnerBattery") ?? 0
            let distanceUnit = defaults?.string(forKey: "distanceUnit") ?? "mi"
            let myName = defaults?.string(forKey: "myName") ?? "Me"
            let partnerName = defaults?.string(forKey: "partnerName") ?? "P"
            let partnerMessage = defaults?.string(forKey: "partnerMessage")
            let anniversaryTimestamp = defaults?.object(forKey: "anniversaryDate") as? Double
            let anniversaryDate = anniversaryTimestamp.map { Date(timeIntervalSince1970: $0) }

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
                batteryLevel: battery,
                noteImage: downloadedImage,
                distanceUnit: distanceUnit,
                myName: myName,
                partnerName: partnerName,
                partnerMessage: partnerMessage,
                anniversaryDate: anniversaryDate
            )
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let distance: Double
    let batteryLevel: Int
    let noteImage: UIImage?
    let distanceUnit: String
    let myName: String
    let partnerName: String
    let partnerMessage: String?
    let anniversaryDate: Date?
}

// MARK: - Widget 1: Status View (Battery & Distance)
struct StatusWidgetView: View {
    var entry: Provider.Entry

    private var isKilometers: Bool {
        entry.distanceUnit == "km"
    }

    private var convertedDistance: Double {
        isKilometers ? entry.distance * 1.609344 : entry.distance
    }

    private var distanceUnitLabel: String {
        isKilometers ? "km away" : "miles away"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.pink.opacity(0.5), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .font(.title3)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: batteryIcon(for: entry.batteryLevel))
                        Text("\(entry.batteryLevel)%")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }

                Spacer()

                Text(entry.distance > 0 ? String(format: "%.0f", convertedDistance) : "--")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(distanceUnitLabel)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
            }
            .padding()
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    func batteryIcon(for level: Int) -> String {
        if level > 80 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 20 { return "battery.50" }
        return "battery.25"
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
        ZStack {
            LinearGradient(colors: [Color.pink.opacity(0.1), Color.white], startPoint: .top, endPoint: .bottom)
            
            VStack(spacing: 16) {
                HStack(spacing: -16) {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                        .zIndex(1)
                    
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                        .zIndex(0)
                }
                .overlay(alignment: .bottom) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.pink)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(y: 10)
                }
                
                VStack(spacing: 2) {
                    Text(dayText)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    Text("Days Together")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Widget Configurations
struct StatusWidget: Widget {
    let kind: String = "StatusWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Partner Status")
        .description("See your partner's distance and battery.")
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
