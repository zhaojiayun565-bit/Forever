import SwiftUI

/// Collects the partner's pairing code until `currentCouple` is set by `AppStateManager`.
struct PairingView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasSkippedPairing") private var hasSkippedPairing = false

    @State private var partnerCode = ""
    @State private var isCopied = false
    @State private var errorMessage: String?
    @State private var isLinking = false

    var myCode: String {
        state.currentUser?.pairingCode ?? "000-000"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground)
                .ignoresSafeArea()

            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                Text("Connect with your other half")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 24) {
                            Button(action: copyCodeToClipboard) {
                                HStack(spacing: 12) {
                                    Image(systemName: isCopied ? "checkmark" : "square.on.square")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(isCopied ? .green : .secondary)
                                        .contentTransition(.symbolEffect(.replace))

                                    Text(myCode)
                                        .font(.system(size: 38, weight: .bold, design: .rounded))
                                        .tracking(2)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button(action: shareCode) {
                                Text("Share code with partner")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(Color.primary)
                                    .foregroundStyle(Color(.systemBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(BubblyButtonStyle())
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
                        .padding(.horizontal, 16)

                        VStack(spacing: 20) {
                            Text("Enter your partner's code")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)

                            TextField("Enter the code", text: $partnerCode)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .textContentType(.oneTimeCode)
                                .textInputAutocapitalization(.characters)
                                .multilineTextAlignment(.center)
                                .keyboardType(.default)
                                .padding(.vertical, 16)
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
                                    } else {
                                        Text("Link phones")
                                    }
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(isLinkEnabled ? Color.pink : Color.secondary.opacity(0.2))
                                .foregroundStyle(isLinkEnabled ? .white : .secondary)
                                .clipShape(Capsule())
                                .animation(.smooth(duration: 0.2), value: isLinkEnabled)
                            }
                            .disabled(!isLinkEnabled || isLinking)
                            .buttonStyle(BubblyButtonStyle())
                        }
                        .padding(24)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                        Button(action: {
                            withAnimation(.smooth) { hasSkippedPairing = true }
                        }) {
                            Text("Skip for now")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 20, y: -5)
            .transition(.move(edge: .bottom))
        }
    }

    private var isLinkEnabled: Bool {
        partnerCode.trimmingCharacters(in: .whitespacesAndNewlines).count >= 6
    }

    // MARK: - Actions

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

    private func shareCode() {
        let textToShare = "Let's connect on Forever! My pairing code is \(myCode)"
        let activityViewController = UIActivityViewController(
            activityItems: [textToShare],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityViewController, animated: true)
        }
    }

    private func linkPhones() {
        Task {
            isLinking = true
            errorMessage = nil
            defer { isLinking = false }
            do {
                try await state.linkWithPartner(code: partnerCode)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
