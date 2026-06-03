import SwiftUI

/// Collects the partner's pairing code until `currentCouple` is set by `AppStateManager`.
struct PairingView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSkippedPairing") private var hasSkippedPairing = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage(OnboardingFlowStorage.postAuthCreatorFunnel) private var postAuthCreatorFunnel = false
    @AppStorage(OnboardingFlowStorage.isInvitedPartner) private var persistedInvitedPartner = false

    @State private var partnerCode = ""
    @State private var isCopied = false
    @State private var errorMessage: String?
    @State private var isLinking = false
    @State private var isSkipping = false

    var myCode: String {
        state.currentUser?.pairingCode ?? "000-000"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Connect with your other half")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Button(action: copyCodeToClipboard) {
                            HStack(spacing: 12) {
                                Image(systemName: isCopied ? "checkmark" : "square.on.square")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(isCopied ? .green : .pink)
                                    .contentTransition(.symbolEffect(.replace))

                                Text(myCode)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .tracking(2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)

                        ShareLink(item: "Let's connect on Forever! My pairing code is \(myCode)") {
                            Text("Share code with partner")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primary)
                                .foregroundStyle(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(24)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                        Text("OR")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 16) {
                        Text("Enter your partner's code")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        TextField("Enter the code", text: $partnerCode)
                            .font(.headline)
                            .textContentType(.oneTimeCode)
                            .textInputAutocapitalization(.characters)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button(action: linkPhones) {
                            Group {
                                if isLinking {
                                    ProgressView()
                                        .tint(isLinkEnabled ? .white : .secondary)
                                } else {
                                    Text("Link phones")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(isLinkEnabled ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isLinkEnabled ? Color.pink : Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .animation(.smooth(duration: 0.2), value: isLinkEnabled)
                        }
                        .disabled(!isLinkEnabled || isLinking)
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(24)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Button(action: { Task { await handleSkipForNow() } }) {
                        Group {
                            if isSkipping {
                                ProgressView()
                            } else {
                                Text("Skip for now")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                    }
                    .disabled(isSkipping)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var isLinkEnabled: Bool {
        partnerCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6
    }

    // MARK: - Actions

    /// Routes to home if premium, or resumes creator onboarding at the map step.
    private func handleSkipForNow() async {
        isSkipping = true
        defer { isSkipping = false }

        await subscription.refresh()
        await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: state)

        await MainActor.run {
            withAnimation(.smooth) {
                hasSkippedPairing = true
                persistedInvitedPartner = false

                if subscription.isPro {
                    // Path B: already premium — go straight to home.
                } else {
                    // Path A: resume creator funnel from the map demo.
                    postAuthCreatorFunnel = true
                    hasCompletedOnboarding = false
                }
                dismiss()
            }
        }
    }

    private func copyCodeToClipboard() {
        UIPasteboard.general.string = myCode

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }

    private func linkPhones() {
        Task {
            isLinking = true
            errorMessage = nil
            defer { isLinking = false }
            do {
                try await state.linkWithPartner(code: partnerCode)
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
