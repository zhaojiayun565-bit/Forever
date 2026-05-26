import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct CherishedTextEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
    let extractedText: String
    let dateAdded: Date?
}

struct CherishedTextProvider: TimelineProvider {
    func placeholder(in context: Context) -> CherishedTextEntry {
        CherishedTextEntry(
            date: Date(),
            image: nil,
            extractedText: "Every little message matters.",
            dateAdded: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CherishedTextEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CherishedTextEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            ?? Date().addingTimeInterval(86_400)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    /// Fetches cherished texts from the shared App Group store and picks one at random.
    private func makeEntry() -> CherishedTextEntry {
        let context = ModelContext(SharedDatabase.shared)
        let descriptor = FetchDescriptor<CherishedText>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )

        guard
            let items = try? context.fetch(descriptor),
            let chosen = items.randomElement()
        else {
            return CherishedTextEntry(date: Date(), image: nil, extractedText: "", dateAdded: nil)
        }

        return CherishedTextEntry(
            date: Date(),
            image: UIImage(data: chosen.imageData),
            extractedText: chosen.extractedText,
            dateAdded: chosen.dateAdded
        )
    }
}

struct CherishedTextWidgetView: View {
    let entry: CherishedTextEntry

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = entry.image {
                    foregroundScreenshot(image: image, size: geometry.size)
                } else {
                    emptyState
                }
            }
        }
        .containerBackground(for: .widget) {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 28)
                    .overlay(Color.black.opacity(0.3))
            } else {
                LinearGradient(
                    colors: [Color.pink.opacity(0.35), Color.purple.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func foregroundScreenshot(image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(
                maxWidth: size.width - 20,
                maxHeight: size.height - 20
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 0.75)
            }
            .padding(10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))

            Text("Cherished Texts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text("Save a screenshot to begin")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct CherishedTextWidget: Widget {
    let kind = "CherishedTextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CherishedTextProvider()) { entry in
            CherishedTextWidgetView(entry: entry)
        }
        .configurationDisplayName("Cherished Text")
        .description("A daily glimpse at a message you saved.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    CherishedTextWidget()
} timeline: {
    CherishedTextEntry(
        date: .now,
        image: nil,
        extractedText: "Thinking of you.",
        dateAdded: .now
    )
}
