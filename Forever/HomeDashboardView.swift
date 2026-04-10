import SwiftUI

struct HomeDashboardView: View {
    @Environment(AppStateManager.self) private var state

    @State private var displayName = ""
    @State private var anniversaryDate = Date()
    @State private var lockMessage = ""

    @State private var isSavingDetails = false
    @State private var isSendingMessage = false
    @State private var isShowingDrawing = false

    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileDetailsCard
                    partnerSummaryCard
                    lockScreenMessageCard
                    drawingCardButton
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .onAppear(perform: seedFieldsFromProfile)
            .alert("Something went wrong", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .fullScreenCover(isPresented: $isShowingDrawing) {
                DrawingView()
                    .environment(state)
            }
        }
    }

    private var profileDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Details")
                .font(.headline)

            TextField("Display name", text: $displayName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            DatePicker(
                "Anniversary Date",
                selection: $anniversaryDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            Button {
                Task { await saveDetails() }
            } label: {
                HStack {
                    if isSavingDetails {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isSavingDetails ? "Saving..." : "Save Details")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSavingDetails || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var partnerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Partner")
                .font(.headline)

            let partnerName = state.partnerProfile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            Text("Name: \((partnerName?.isEmpty == false) ? partnerName! : "Not set")")
                .foregroundStyle(.primary)

            Text("Days Together: \(daysTogetherText)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var lockScreenMessageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lock Screen Message")
                .font(.headline)

            TextField("Write a short message", text: $lockMessage)
                .textInputAutocapitalization(.sentences)
                .lineLimit(2)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await sendMessage() }
            } label: {
                HStack {
                    if isSendingMessage {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isSendingMessage ? "Sending..." : "Send")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isSendingMessage || lockMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var drawingCardButton: some View {
        Button {
            isShowingDrawing = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pencil.and.scribble")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Draw a Note")
                        .font(.headline)
                    Text("Open a full-screen canvas for your partner")
                        .font(.subheadline)
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .purple.opacity(0.25), radius: 12, y: 6)
    }

    /// Prefills local form state from the current profile.
    private func seedFieldsFromProfile() {
        if let existingName = state.currentUser?.displayName {
            displayName = existingName
        }
        if let existingAnniversary = state.currentUser?.anniversaryDate {
            anniversaryDate = existingAnniversary
        }
    }

    /// Picks partner anniversary first, then falls back to user anniversary.
    private var effectiveAnniversaryDate: Date? {
        state.partnerProfile?.anniversaryDate ?? state.currentUser?.anniversaryDate
    }

    /// Human-readable day count since anniversary date.
    private var daysTogetherText: String {
        guard let anniversary = effectiveAnniversaryDate else { return "Not available yet" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: anniversary), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return "\(max(days, 0))"
    }

    /// Saves profile details and updates local app state.
    private func saveDetails() async {
        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }

        isSavingDetails = true
        defer { isSavingDetails = false }

        do {
            try await SupabaseManager.shared.updateProfileDetails(name: cleanedName, anniversary: anniversaryDate)
            if state.currentUser == nil { return }
            state.currentUser?.displayName = cleanedName
            state.currentUser?.anniversaryDate = anniversaryDate
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Sends a lock screen message for widgets and partner sync.
    private func sendMessage() async {
        let cleanedMessage = lockMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedMessage.isEmpty else { return }

        isSendingMessage = true
        defer { isSendingMessage = false }

        do {
            try await SupabaseManager.shared.sendLockScreenMessage(cleanedMessage)
            lockMessage = ""
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    HomeDashboardView()
        .environment(AppStateManager())
}
