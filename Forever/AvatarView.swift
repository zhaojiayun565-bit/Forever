import SwiftUI
import Kingfisher

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 64
    
    var body: some View {
        ZStack {
            if let url = url {
                KFImage.url(url)
                    .placeholder { nativeFallback }
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                nativeFallback
            }
        }
        .frame(width: size, height: size)
    }
    
    private var nativeFallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color(UIColor.systemGray3))
    }
}
