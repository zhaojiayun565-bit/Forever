import SwiftUI
import Kingfisher

/// Circular profile avatar with glass monogram chrome and optional remote photo.
struct AvatarView: View {
    let url: URL?
    let name: String
    var localImage: UIImage?
    var size: CGFloat = 64
    var style: ForeverMonogramStyle = .glassLight

    var body: some View {
        Group {
            if let localImage {
                ForeverMonogramBubble(
                    name: name,
                    image: localImage,
                    size: size,
                    style: style
                )
            } else if let url {
                KFImage.url(url)
                    .placeholder {
                        ForeverMonogramBubble(name: name, size: size, style: style)
                    }
                    .resizable()
                    .scaledToFill()
                    .foreverMonogramChrome(size: size, style: style)
            } else {
                ForeverMonogramBubble(name: name, size: size, style: style)
            }
        }
    }
}
