import SwiftUI

/// Multi-line answer input sheet shared by daily and category flows.
struct QuestionAnswerSheet: View {
    let questionText: String
    let isSubmitting: Bool
    let onSubmit: (String) async -> Bool
    let onDismiss: () -> Void

    @State private var response = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(questionText)
                    .font(ForeverFont.header(.title3))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $response)
                    .font(ForeverFont.body(.body))
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .focused($isFocused)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Your Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if await onSubmit(trimmed) {
                                onDismiss()
                            }
                        }
                    }
                    .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
