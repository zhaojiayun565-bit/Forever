import SwiftUI

struct ArchiveView: View {
    @Environment(AppStateManager.self) private var state

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if state.archiveNotes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink.opacity(0.5), .purple.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("No memories yet")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text("Drawings you send each other will automatically be saved here forever.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(state.archiveNotes) { note in
                            ArchiveNoteCard(note: note, state: state)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Memories")
            .refreshable {
                await state.loadArchive()
            }
            .task {
                if state.archiveNotes.isEmpty {
                    await state.loadArchive()
                }
            }
        }
    }
}

struct ArchiveNoteCard: View {
    let note: ArchiveNote
    let state: AppStateManager

    var senderName: String {
        if note.isFromMe {
            return state.currentUser?.displayName ?? "You"
        } else {
            return state.partnerProfile?.displayName ?? "Partner"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: note.url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    ZStack {
                        Color.gray.opacity(0.1)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red.opacity(0.5))
                    }
                } else {
                    ZStack {
                        Color.gray.opacity(0.1)
                        ProgressView()
                    }
                }
            }
            .frame(height: 160)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)

            HStack {
                Text(senderName)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(note.isFromMe ? .blue : .pink)

                Spacer()

                Text(note.createdAt.formatted(.dateTime.month().day()))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
        }
    }
}
