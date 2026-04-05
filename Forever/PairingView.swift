import SwiftUI

/// Collects the partner’s pairing code until `currentCouple` is set by `AppStateManager`.
struct PairingView: View {
    @Environment(AppStateManager.self) private var state
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLinking = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair with your partner")
                .font(.title2.weight(.semibold))
            Text("Ask them for their 6-digit code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Code", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .padding()
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

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
                    Text("Pair")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLinking)
        }
        .padding()
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

#Preview {
    PairingView()
        .environment(AppStateManager())
}
