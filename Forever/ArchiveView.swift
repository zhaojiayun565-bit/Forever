import Kingfisher
import SwiftUI
import UIKit

struct ArchiveView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundStyle(.quaternary)
                Text("Memories")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Past notes and messages will appear here soon.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Archive")
        }
    }
}

// MARK: - Note card (Kingfisher + downsampled thumbnail)

struct ArchiveNoteCard: View {
    let url: URL

    var body: some View {
        KFImage.url(url)
            .placeholder {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
            }
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 300, height: 300)))
            .scaleFactor(UIScreen.main.scale)
            .cacheOriginalImage()
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

#Preview("Archive note card") {
    ArchiveNoteCard(url: URL(string: "https://picsum.photos/400")!)
        .frame(width: 160, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
