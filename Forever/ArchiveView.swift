import SwiftUI

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
