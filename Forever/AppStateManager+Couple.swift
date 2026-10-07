import Foundation
import Supabase
import WidgetKit

/// Couple lifecycle: Realtime listeners, partner-initiated unpair, and foreground recovery.
extension AppStateManager {
    private var coupleLinkTopic: String? {
        currentUser.map { "couple-link-\($0.id)" }
    }

    /// Listens for the partner entering our code while we're unpaired.
    func startCoupleLinkListener() {
        guard let topic = coupleLinkTopic else { return }
        realtime.start(topic) { [weak self] channel in
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "couples")
            return {
                for await _ in inserts {
                    guard let self, let couple = try? await self.supabase.fetchCurrentCouple() else { continue }
                    // didPair stops this listener, so run it outside the listener task.
                    Task { await self.didPair(with: couple) }
                    return
                }
            }
        }
    }

    /// Starts partner-profile, memories, and couple-deletion listeners for the current couple.
    func startCoupleListeners() {
        guard let couple = currentCouple, let myId = currentUser?.id else { return }
        if let coupleLinkTopic { realtime.stop(coupleLinkTopic) }
        let partnerId = couple.user1Id == myId ? couple.user2Id : couple.user1Id

        realtime.start("partner-profile-\(partnerId)") { [weak self] channel in
            let updates = channel.postgresChange(
                UpdateAction.self, schema: "public", table: "profiles", filter: .eq("id", value: partnerId)
            )
            return {
                for await _ in updates {
                    guard let self else { return }
                    await self.loadPartnerProfile()
                    await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
                }
            }
        }

        realtime.start("couple-memories-\(couple.id)") { [weak self] channel in
            let filter = RealtimePostgresFilter.eq("couple_id", value: couple.id)
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "memories", filter: filter)
            let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "memories", filter: filter)
            let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "memories", filter: filter)
            let reload: @MainActor @Sendable () async -> Void = { [weak self] in await self?.loadMemories() }
            return {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { for await _ in inserts { await reload() } }
                    group.addTask { for await _ in updates { await reload() } }
                    group.addTask { for await _ in deletes { await reload() } }
                }
            }
        }

        // Delete events can't be filtered server-side; match the couple id client-side.
        realtime.start("couple-status-\(couple.id)") { [weak self] channel in
            let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "couples")
            return {
                for await action in deletes {
                    guard let self,
                          let id = action.oldRecord["id"]?.stringValue.flatMap(UUID.init(uuidString:)),
                          id == couple.id else { continue }
                    // resetCoupleState stops this listener, so run it outside the listener task.
                    Task { await self.resetCoupleState() }
                    return
                }
            }
        }
    }

    /// Clears couple + partner state locally (after either partner unpairs) and waits to be paired again.
    func resetCoupleState() async {
        await realtime.stopAll()
        currentCouple = nil
        partnerProfile = nil
        memories.removeAll()
        clearPartnerWidgetData()
        WidgetCenter.shared.reloadAllTimelines()
        startCoupleLinkListener()
        await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
        OnboardingFlowStorage.clearInvitePairingEntryOnly()
    }

    /// Foreground refresh: catches an unpair or pairing missed while suspended, restarts Realtime
    /// (sockets drop in the background), and re-syncs location and memories.
    func refreshOnForeground() async {
        guard currentUser != nil, !isLoading else { return }
        let latestCouple: Couple?
        do {
            latestCouple = try await supabase.fetchCurrentCouple()
        } catch {
            return
        }

        switch (currentCouple, latestCouple) {
        case (.some, nil):
            await resetCoupleState()
        case (nil, .some(let couple)):
            await didPair(with: couple)
        case (.some, .some(let couple)):
            currentCouple = couple
            startCoupleListeners()
            await syncAndRefreshWidgets()
            await loadMemories()
        case (nil, nil):
            startCoupleLinkListener()
        }
    }

    /// Uploads location right away (bypassing the throttle), e.g. just after permission is granted.
    func syncLocationNow() async {
        guard currentCouple != nil else { return }
        AmbientDataManager.shared.resetUploadThrottle()
        await syncAndRefreshWidgets()
    }
}
