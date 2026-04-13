import SwiftUI

struct SettingsView: View {
    @Environment(AppStateManager.self) private var state
    @State private var displayName = ""
    @State private var anniversary = Date()
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Couple Details") {
                    TextField("Your Display Name", text: $displayName)
                    DatePicker("Anniversary", selection: $anniversary, displayedComponents: .date)
                    
                    Button {
                        Task {
                            isSaving = true
                            try? await SupabaseManager.shared.updateProfileDetails(name: displayName, anniversary: anniversary)
                            await state.initializeApp() // Refresh state
                            isSaving = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Details")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(displayName.isEmpty)
                }
                
                Section("Pairing") {
                    HStack {
                        Text("Your Invite Code")
                        Spacer()
                        Text(state.currentUser?.pairingCode ?? "----")
                            .font(.system(.body, design: .monospaced).weight(.bold))
                            .foregroundStyle(.blue)
                    }
                }
                
                Section("About") {
                    Link("Terms of Service", destination: URL(string: "https://apple.com")!)
                    Link("Privacy Policy", destination: URL(string: "https://apple.com")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let name = state.currentUser?.displayName { displayName = name }
                if let date = state.currentUser?.anniversaryDate { anniversary = date }
            }
        }
    }
}
