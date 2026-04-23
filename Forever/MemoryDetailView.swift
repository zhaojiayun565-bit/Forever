import Kingfisher
import SwiftUI
import UIKit

struct MemoryDetailView: View {
    let memory: CoupleMemory
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStateManager.self) private var state

    @State private var showingDeleteAlert = false
    @State private var isDeleting = false

    @State private var showingEditSheet = false
    @State private var actionErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                TabView {
                    ForEach(memory.imageUrls, id: \.self) { url in
                        KFImage.url(url)
                            .placeholder { ProgressView().tint(.white) }
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 8)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: memory.imageUrls.count > 1 ? .always : .never))
                .padding(.bottom, memory.note?.isEmpty == false ? 100 : 40)

                if let note = memory.note, !note.isEmpty {
                    VStack {
                        Text(note)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(20)
                    .padding(.bottom, 20)
                }

                if isDeleting {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Memory", systemImage: "pencil") {
                            showingEditSheet = true
                        }

                        Button("Delete Memory", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
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
            print("🚨 Failed to delete: \(error)")
            isDeleting = false
        }
    }
}
