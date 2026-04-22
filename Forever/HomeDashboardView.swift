import SwiftUI
import CoreLocation

struct HomeDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("distanceUnit") private var distanceUnit = "mi"
    @State private var lockScreenMessage = ""
    @State private var isDrawing = false
    
    var daysTogether: Int {
        guard let date = state.currentUser?.anniversaryDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    private var distanceInMiles: Double? {
        guard
            let myLat = state.currentUser?.latitude,
            let myLon = state.currentUser?.longitude,
            let partnerLat = state.partnerProfile?.latitude,
            let partnerLon = state.partnerProfile?.longitude
        else {
            return nil
        }
        let myLocation = CLLocation(latitude: myLat, longitude: myLon)
        let partnerLocation = CLLocation(latitude: partnerLat, longitude: partnerLon)
        return myLocation.distance(from: partnerLocation) / 1609.344
    }

    private var isKilometers: Bool {
        distanceUnit == "km"
    }

    private var displayDistanceValue: String {
        guard let miles = distanceInMiles, miles > 0 else { return "--" }
        let value = isKilometers ? miles * 1.609344 : miles
        return String(format: "%.0f", value)
    }

    private var displayDistanceUnit: String {
        isKilometers ? "km away" : "miles away"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if state.currentCouple == nil {
                        BubblyCard {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )

                                Text("You're exploring solo!")
                                    .font(.system(.headline, design: .rounded))

                                Text("Your invite code is **\(state.currentUser?.pairingCode ?? "----")**. Head to the **Me** tab to link with your partner and unlock everything.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // HERO: Days Together
                    BubblyCard {
                        VStack(spacing: 8) {
                            Text("We've been together for")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(daysTogether)")
                                    .font(.system(size: 64, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                Text("days")
                                    .font(.system(.title2, design: .rounded).weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    BubblyCard {
                        VStack(spacing: 8) {
                            Text("Distance Apart")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(displayDistanceValue)
                                    .font(.system(size: 52, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                Text(displayDistanceUnit)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // ACTION: Draw Note
                    Button {
                        isDrawing = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Draw a Note")
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                Text("Send to their Home Screen")
                                    .font(.subheadline)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.title)
                        }
                        .padding(24)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                    .buttonStyle(BubblyButtonStyle())
                    
                    // ACTION: Lock Screen Message
                    BubblyCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Lock Screen Message", systemImage: "lock.iphone")
                                .font(.system(.headline, design: .rounded))
                            
                            HStack {
                                TextField("Thinking of you...", text: $lockScreenMessage)
                                    .padding(14)
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                
                                Button {
                                    Task {
                                        try? await SupabaseManager.shared.sendLockScreenMessage(lockScreenMessage)
                                        lockScreenMessage = ""
                                    }
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(lockScreenMessage.isEmpty ? Color.gray.opacity(0.3) : Color.pink)
                                        .clipShape(Circle())
                                }
                                .disabled(lockScreenMessage.isEmpty)
                                .animation(.spring(), value: lockScreenMessage.isEmpty)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Us")
            .fullScreenCover(isPresented: $isDrawing) {
                DrawingView()
            }
        }
    }
}
