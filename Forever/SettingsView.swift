import SwiftUI
import WidgetKit

private enum DistanceUnitOption: String, CaseIterable {
    case miles = "mi"
    case kilometers = "km"

    var label: String {
        switch self {
        case .miles:
            return "Miles (mi)"
        case .kilometers:
            return "Kilometers (km)"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStateManager.self) private var state
    @State private var displayName = ""
    @State private var anniversary = Date()
    @State private var isSaving = false
    @AppStorage("distanceUnit") private var distanceUnit = DistanceUnitOption.miles.rawValue

    private var normalizedDistanceUnit: String {
        DistanceUnitOption(rawValue: distanceUnit)?.rawValue ?? DistanceUnitOption.miles.rawValue
    }

    private func syncDistanceUnitToWidgetDefaults() {
        guard let defaults = UserDefaults(suiteName: "group.forever.widget") else { return }
        let unit = normalizedDistanceUnit
        if defaults.string(forKey: "distanceUnit") != unit {
            defaults.set(unit, forKey: "distanceUnit")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

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

                Section("Preferences") {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnitOption.allCases, id: \.rawValue) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
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

                Section("Account Management") {
                    Button("Sign Out") {
                        Task {
                            try? await SupabaseManager.shared.signOut()
                            await state.initializeApp()
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let name = state.currentUser?.displayName { displayName = name }
                if let date = state.currentUser?.anniversaryDate { anniversary = date }
                if distanceUnit != normalizedDistanceUnit {
                    distanceUnit = normalizedDistanceUnit
                }
                syncDistanceUnitToWidgetDefaults()
            }
            .onChange(of: distanceUnit) { _, _ in
                if distanceUnit != normalizedDistanceUnit {
                    distanceUnit = normalizedDistanceUnit
                }
                syncDistanceUnitToWidgetDefaults()
            }
        }
    }
}
