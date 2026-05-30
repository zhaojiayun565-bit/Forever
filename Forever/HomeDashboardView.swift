import SwiftUI
import CoreLocation

struct HomeDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("distanceUnit") private var distanceUnit = "mi"
    @State private var lockScreenMessage = ""
    @State private var showingDrawingBoard = false
    @State private var showingPairingRequiredAlert = false
    
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
                    
                    // 2. THE HERO CARD
                    DaysTogetherHeroCard()

                    NavigationLink {
                        CherishedTextsView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title2)
                                .foregroundStyle(.pink)
                                .frame(width: 44, height: 44)
                                .background(.pink.opacity(0.15), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cherished Texts")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Our favorite saved messages")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if state.currentCouple == nil {
                            showingPairingRequiredAlert = true
                        } else {
                            showingDrawingBoard = true
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "scribble.variable")
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 44, height: 44)
                                .background(.purple.opacity(0.15), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Drawing Board")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Doodle together on a shared lock screen")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)

                    // 3. THE MAP STATS CARD
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
            .fullScreenCover(isPresented: $showingDrawingBoard) {
                LockscreenDrawingBoardView()
                    .environment(state)
            }
            .alert("Pairing Required", isPresented: $showingPairingRequiredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Pair with your partner to unlock the Shared Drawing Board.")
            }
        }
    }
}

struct DaysTogetherHeroCard: View {
    @Environment(AppStateManager.self) private var state
    
    var daysTogether: Int {
        guard let date = state.currentUser?.anniversaryDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return max(0, days)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                AvatarView(
                    url: state.currentUser?.avatarUrl.flatMap { URL(string: $0) },
                    name: state.currentUser?.displayName ?? "Me",
                    size: 72
                )
                AvatarView(
                    url: state.partnerProfile?.avatarUrl.flatMap { URL(string: $0) },
                    name: state.partnerProfile?.displayName ?? "Partner",
                    size: 72
                )
            }
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.pink)
                    .padding(6)
                    .background(Color.black)
                    .clipShape(Circle())
            }
            
            VStack(spacing: -2) {
                Text("\(daysTogether)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("DAYS")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.gray)
                    .tracking(2)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}
