import SwiftUI
import WidgetKit

// MARK: - Timeline

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), distance: 456.0, batteryLevel: 85)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), distance: 456.0, batteryLevel: 85)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.forever.widget")

        let distance = defaults?.double(forKey: "partnerDistance") ?? 0.0
        let battery = defaults?.integer(forKey: "partnerBattery") ?? 0

        let entry = SimpleEntry(date: Date(), distance: distance, batteryLevel: battery)

        // Policy is .never because the main app forces the reload via WidgetCenter
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let distance: Double
    let batteryLevel: Int
}

// MARK: - View

struct CoupleWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                    .font(.title3)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon(for: entry.batteryLevel))
                    Text("\(entry.batteryLevel)%")
                        .font(.caption2.bold())
                }
                .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Text(entry.distance > 0 ? String(format: "%.0f", entry.distance) : "--")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("miles away")
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.8))
                .textCase(.uppercase)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.pink.opacity(0.5), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func batteryIcon(for level: Int) -> String {
        if level > 80 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 20 { return "battery.50" }
        return "battery.25"
    }
}

// MARK: - Widget

@main
struct CoupleWidget: Widget {
    let kind: String = "CoupleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CoupleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Partner Status")
        .description("See how far away your partner is in real-time.")
        .supportedFamilies([.systemSmall])
    }
}
