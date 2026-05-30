import SwiftUI
import Kingfisher

/// Circular profile avatar: remote photo when available, otherwise a Find My-style monogram.
struct AvatarView: View {
    let url: URL?
    let name: String
    var localImage: UIImage?
    var size: CGFloat = 64

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        Group {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let url {
                KFImage.url(url)
                    .placeholder { monogramFallback }
                    .resizable()
                    .scaledToFill()
            } else {
                monogramFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }

    private var monogramFallback: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray3))
            Text(initial)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
