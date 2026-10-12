import SwiftUI

/// Shared Albums–style comment thread for a paired memory, presented as a resizable sheet.
struct MemoryCommentsSheet: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: MemoryCommentsViewModel
    @State private var draft = ""

    init(memoryId: UUID, realtime: RealtimeListenerRegistry) {
        _viewModel = State(initialValue: MemoryCommentsViewModel(memoryId: memoryId, realtime: realtime))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        }
        .presentationBackground(Color(uiColor: .systemBackground))
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.reload() }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.comments.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.comments.isEmpty {
            ContentUnavailableView(
                "No Comments Yet",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Start the conversation about this memory.")
            )
        } else {
            thread
        }
    }

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.comments) { comment in
                        MemoryCommentRow(
                            comment: comment,
                            author: author(of: comment),
                            onDelete: { Task { await viewModel.delete(comment) } }
                        )
                        .id(comment.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.comments.last?.id) { _, lastId in
                guard let lastId else { return }
                withAnimation(.smooth) { proxy.scrollTo(lastId, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Add a comment", text: $draft, axis: .vertical)
                .font(ForeverFont.body(.body))
                .lineLimit(1...)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

            Button {
                Task { await submit() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
            .tint(.pink)
            .disabled(!canSend)
            .accessibilityLabel("Post Comment")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    /// Posts the draft; keeps it in the field if the post fails.
    private func submit() async {
        guard let authorId = state.currentUser?.id else { return }
        let text = draft
        draft = ""
        if !(await viewModel.send(text, authorId: authorId)) {
            draft = text
        }
    }

    /// Resolves how the comment's author is shown: the current user or their partner.
    private func author(of comment: MemoryComment) -> MemoryCommentAuthor {
        if comment.authorId == state.currentUser?.id {
            return MemoryCommentAuthor(
                name: state.currentUser?.displayName ?? "You",
                avatarURL: state.currentUser?.avatarUrl.flatMap(URL.init(string:)),
                localAvatar: state.myAvatarImage,
                isCurrentUser: true
            )
        }
        return MemoryCommentAuthor(
            name: state.partnerDisplayName,
            avatarURL: state.partnerProfile?.avatarUrl.flatMap(URL.init(string:)),
            localAvatar: nil,
            isCurrentUser: false
        )
    }
}

/// Display details for a comment's author.
struct MemoryCommentAuthor {
    let name: String
    let avatarURL: URL?
    let localAvatar: UIImage?
    let isCurrentUser: Bool
}

/// One comment: avatar, author name, relative time, and body; long-press to copy or delete your own.
struct MemoryCommentRow: View {
    let comment: MemoryComment
    let author: MemoryCommentAuthor
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: author.avatarURL, name: author.name, localImage: author.localAvatar, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(author.name)
                        .font(ForeverFont.bold(.subheadline))
                    Text(comment.createdAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(ForeverFont.body(.caption))
                        .foregroundStyle(.secondary)
                }
                Text(comment.body)
                    .font(ForeverFont.body(.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = comment.body
            }
            if author.isCurrentUser {
                Button("Delete Comment", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
