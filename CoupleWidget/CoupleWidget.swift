import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), distance: 456.0, batteryLevel: 85, noteImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), distance: 456.0, batteryLevel: 85, noteImage: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let defaults = UserDefaults(suiteName: "group.forever.widget")
            let distance = defaults?.double(forKey: "partnerDistance") ?? 0.0
            let battery = defaults?.integer(forKey: "partnerBattery") ?? 0

            var downloadedImage: UIImage? = nil

            // Download the note image if URL exists
            if let urlString = defaults?.string(forKey: "partnerNoteUrl"),
               let url = URL(string: urlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    downloadedImage = UIImage(data: data)
                } catch {
                    print("🚨 Widget Image Download Failed: \(error)")
                }
            }

            let entry = SimpleEntry(date: Date(), distance: distance, batteryLevel: battery, noteImage: downloadedImage)
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
}

struct CoupleWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            // 1. The Background (Gradient or Note)
            if let image = entry.noteImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color.pink.opacity(0.5), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // 2. The Data Overlay
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .font(.title3)
                        // Add shadow so it's readable over drawings
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

                // Only show distance if there ISN'T a drawing, to keep the drawing clean
                if entry.noteImage == nil {
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

@main
struct CoupleWidget: Widget {
    let kind: String = "CoupleWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CoupleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Partner Status")
        .description("See your partner's notes and distance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
