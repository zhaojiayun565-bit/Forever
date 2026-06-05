import SwiftUI
import CoreLocation

struct HomeDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("distanceUnit") private var distanceUnit = "mi"
    @State private var lockScreenMessage = ""
    @State private var showingDrawingBoard = false
    @State private var showingPairingRequiredAlert = false
    @State private var showPairingSheet = false
    @State private var dailyQuestionVM = DailyQuestionViewModel()
    @State private var showDailyAnswerSheet = false

    private var partnerName: String {
        state.partnerProfile?.displayName ?? String(localized: "Partner")
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
                    // 2. THE HERO CARD
                    DaysTogetherHeroCard()

                    if let couple = state.currentCouple,
                       let userId = state.currentUser?.id,
                       let question = dailyQuestionVM.question {
                        DailyQuestionCard(
                            questionText: question.questionText,
                            partnerName: partnerName,
                            revealState: dailyQuestionVM.revealState,
                            myAnswer: dailyQuestionVM.answer?.myResponse(for: userId),
                            partnerAnswer: dailyQuestionVM.answer?.partnerResponse(for: userId),
                            streakCount: couple.questionsStreakCount,
                            onAnswerTapped: { showDailyAnswerSheet = true }
                        )
                    }

                    if state.currentCouple == nil {
                        PairingCardView {
                            showPairingSheet = true
                        }
                    }

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
                                    .font(ForeverFont.header(.headline))
                                    .foregroundStyle(.primary)
                                Text("Our favorite saved messages")
                                    .font(ForeverFont.subheader(.subheadline))
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
                                    .font(ForeverFont.header(.headline))
                                    .foregroundStyle(.primary)
                                Text("Doodle together on a shared lock screen")
                                    .font(ForeverFont.subheader(.subheadline))
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
                                .font(ForeverFont.subheader(.subheadline))
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(displayDistanceValue)
                                    .font(ForeverFont.header(size: 52, relativeTo: .largeTitle))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                Text(displayDistanceUnit)
                                    .font(ForeverFont.bold(.title3))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // ACTION: Lock Screen Message
                    BubblyCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Lock Screen Message", systemImage: "lock.iphone")
                                .font(ForeverFont.header(.headline))
                            
                            HStack {
                                TextField("Thinking of you...", text: $lockScreenMessage)
                                    .font(ForeverFont.body(.body))
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
            .task(id: state.currentCouple?.id) {
                await dailyQuestionVM.load(
                    couple: state.currentCouple,
                    currentUserId: state.currentUser?.id
                )
            }
            .onChange(of: dailyQuestionVM.revealState) { _, revealState in
                if revealState == .revealed {
                    Task { await state.refreshCurrentCouple() }
                }
            }
            .sheet(isPresented: $showDailyAnswerSheet) {
                if let question = dailyQuestionVM.question {
                    QuestionAnswerSheet(
                        questionText: question.questionText,
                        isSubmitting: dailyQuestionVM.isSubmitting,
                        onSubmit: { text in
                            await dailyQuestionVM.submitAnswer(text)
                        },
                        onDismiss: { showDailyAnswerSheet = false }
                    )
                }
            }
            .fullScreenCover(isPresented: $showingDrawingBoard) {
                LockscreenDrawingBoardView()
                    .environment(state)
            }
            .alert("Pairing Required", isPresented: $showingPairingRequiredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Pair with your partner to unlock the Shared Drawing Board.")
            }
            .fullScreenCover(isPresented: $showPairingSheet) {
                PairingView(usesInviteEntryLayout: false)
                    .environment(state)
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
                    localImage: state.myAvatarImage,
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
                    .font(ForeverFont.header(size: 64, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                
                Text("DAYS")
                    .font(ForeverFont.bold(.subheadline))
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
