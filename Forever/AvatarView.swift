import SwiftUI
import Kingfisher

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 64
    var outlineColor: Color = Color(UIColor.systemBackground)
    
    var body: some View {
        ZStack {
            if let url = url {
                KFImage.url(url)
                    .placeholder { fallback }
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(outlineColor, lineWidth: 4))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
    }
    
    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "person.fill")
                .foregroundStyle(.white)
                .font(.system(size: size * 0.4))
        }
    }
}
