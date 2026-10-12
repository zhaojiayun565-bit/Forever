import Kingfisher
import SwiftUI
import UIKit
import os

struct MemoryDetailView: View {
    let memory: CoupleMemory
    var initiallyShowComments = false

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStateManager.self) private var state

    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var currentImageIndex = 0

    @State private var showingEditSheet = false
    @State private var showingComments = false
    @State private var actionErrorMessage: String?

    private var hasNote: Bool {
        memory.note?.isEmpty == false
    }

    /// Comments exist only after pairing, on memories that belong to the couple.
    private var canComment: Bool {
        state.currentCouple != nil && memory.coupleId != nil
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(memory.imageUrls.enumerated()), id: \.element) { index, url in
                        KFImage.url(url)
                            .placeholder { ProgressView() }
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 8)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                if memory.imageUrls.count > 1 {
                    MemoryPageIndicator(
                        count: memory.imageUrls.count,
                        selection: currentImageIndex
                    )
                    .padding(.top, 12)
                    .padding(.bottom, hasNote ? 0 : 24)
                }

                if let note = memory.note, !note.isEmpty {
                    Text(note)
                        .font(ForeverFont.body(.body))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }

            if isDeleting {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if canComment {
                    Button {
                        showingComments = true
                    } label: {
                        Image(systemName: "bubble")
                    }
                    .accessibilityLabel("Comments")
                }

                Menu {
                    Button("Edit Memory", systemImage: "pencil") {
                        showingEditSheet = true
                    }

                    Button("Delete Memory", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .alert("Delete Memory?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text("This will permanently remove this memory for both you and your partner. This cannot be undone.")
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionErrorMessage ?? "Something went wrong.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMemoryView(memory: memory) {
                dismiss()
            }
        }
        .sheet(isPresented: $showingComments) {
            MemoryCommentsSheet(memoryId: memory.id, realtime: state.realtime)
                .environment(state)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if initiallyShowComments, canComment {
                showingComments = true
            }
        }
    }

    private func performDelete() async {
        isDeleting = true
        do {
            try await SupabaseManager.shared.deleteMemory(id: memory.id)
            await state.loadMemories()
            dismiss()
        } catch {
            actionErrorMessage = error.localizedDescription
            Log.data.error("Failed to delete: \(String(describing: error))")
            isDeleting = false
        }
    }
}
