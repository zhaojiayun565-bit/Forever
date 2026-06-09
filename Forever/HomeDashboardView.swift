import SwiftUI

struct HomeDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @State private var lockScreenMessage = ""
    @State private var showingDrawingBoard = false
    @State private var showingPairingRequiredAlert = false
    @State private var showPairingSheet = false
    @State private var dailyQuestionVM = DailyQuestionViewModel()
    @State private var showDailyAnswerSheet = false

    private var partnerName: String {
        state.partnerDisplayName
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
            .onDisappear {
                Task { await dailyQuestionVM.stopRealtime() }
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
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                AvatarView(
                    url: state.currentUser?.avatarUrl.flatMap { URL(string: $0) },
                    name: state.currentUser?.displayName ?? "Me",
                    localImage: state.myAvatarImage,
                    size: 60,
                    style: .glassLight
                )
                AvatarView(
                    url: state.partnerProfile?.avatarUrl.flatMap { URL(string: $0) },
                    name: state.partnerDisplayName,
                    size: 60,
                    style: .glassLight
                )
            }
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.pink)
            }

            VStack(spacing: -2) {
                Text("\(daysTogether)")
                    .font(ForeverFont.header(size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(.primary)

                Text("Days Together")
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}
