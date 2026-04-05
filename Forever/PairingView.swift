import SwiftUI

/// Collects the partner’s pairing code until `currentCouple` is set by `AppStateManager`.
struct PairingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLinking = false

    var body: some View {
        VStack(spacing: 24) {

            // 1. THIS IS THE NEW PART: Display the user's own code
            if let myCode = state.currentUser?.pairingCode {
                VStack(spacing: 8) {
                    Text("Your Invite Code")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(myCode)
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .tracking(4)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.blue)
                }
                .padding(.bottom, 20)
            }

            Divider()
                .padding(.horizontal, 40)

            // 2. The Input Field (Cursor's original code)
            VStack(spacing: 12) {
                Text("Enter Partner's Code")
                    .font(.headline)

                TextField("6-Digit Code", text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.default) // Changed from numberPad to default since codes have letters
                    .textInputAutocapitalization(.characters)
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.bold))
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    await link()
                }
            } label: {
                if isLinking {
                    ProgressView()
                } else {
                    Text("Link Phones")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || isLinking)
        }
        .padding(30)
    }

    private func link() async {
        isLinking = true
        errorMessage = nil
        defer { isLinking = false }
        do {
            try await state.linkWithPartner(code: code)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
