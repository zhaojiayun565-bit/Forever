import CoreLocation
import Foundation
import Observation
import UIKit

/// Onboarding answers kept on device until the user has an account to save them to
/// (users pay before signing in, so nothing can be uploaded during the funnel).
struct OnboardingDraft: Codable, Equatable {
    var myName = ""
    var partnerName = ""
    var anniversary: Date?

    var trimmedMyName: String { myName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPartnerName: String { partnerName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Whether any profile detail was entered and still needs uploading.
    var hasProfileDetails: Bool {
        !trimmedMyName.isEmpty || !trimmedPartnerName.isEmpty || anniversary != nil
    }
}

/// UserDefaults-backed onboarding state shared by onboarding, pairing, and account reset.
enum OnboardingFlowStorage {
    static let postAuthCreatorFunnel = "postAuthCreatorFunnel"
    static let isInvitedPartner = "isInvitedPartner"
    static let invitePairingEntryOnly = "invitePairingEntryOnly"
    static let awaitingSignInAfterPaywall = "onboardingAwaitingSignIn"
    private static let draftKey = "onboardingDraft"

    /// Every key owned by onboarding, for full local resets (e.g. account deletion).
    static let allKeys = [
        postAuthCreatorFunnel,
        isInvitedPartner,
        invitePairingEntryOnly,
        awaitingSignInAfterPaywall,
        draftKey,
        "onboardingCommitmentLevel"
    ]

    /// Clears invite-only pairing layout (e.g. after unpair).
    static func clearInvitePairingEntryOnly() {
        UserDefaults.standard.set(false, forKey: invitePairingEntryOnly)
    }

    static func loadDraft() -> OnboardingDraft {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else { return OnboardingDraft() }
        return draft
    }

    static func saveDraft(_ draft: OnboardingDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
    }

    static func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
}

/// First memory captured during onboarding, kept in memory for the celebration step.
struct OnboardingMemoryPreview {
    let image: UIImage
    let note: String
    let coordinate: CLLocationCoordinate2D
}

/// Which audience the sign-in step is addressing.
enum OnboardingLoginMode {
    case saveProfile, invitedPartner, returningUser
}

/// Owns onboarding step routing, the local draft, and the creator / invited-partner branches.
@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var draft: OnboardingDraft {
        didSet { OnboardingFlowStorage.saveDraft(draft) }
    }
    var selectedRelationshipGoals: [RelationshipGoal] = []
    var featureTab = 0
    var showAddMemory = false
    var memoryPreview: OnboardingMemoryPreview?
    var memoryStageError: String?
    /// True once onboarding is done; the view flips the app-level `hasCompletedOnboarding` flag.
    private(set) var isComplete = false
    private(set) var isInvitedFlow = false
    private(set) var isFinishing = false
    private(set) var isReturningUser = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.draft = OnboardingFlowStorage.loadDraft()
        self.isInvitedFlow = defaults.bool(forKey: OnboardingFlowStorage.isInvitedPartner)
    }

    // MARK: Progress

    var showsProgress: Bool {
        OnboardingStep.progressTrackedSteps.contains(currentStep) && !isInvitedFlow
    }

    var isIntroPhase: Bool {
        currentStep.rawValue <= OnboardingStep.commitmentEncouragement.rawValue
    }

    var progressValue: Double {
        let steps = OnboardingStep.progressTrackedSteps
        return Double((steps.firstIndex(of: currentStep) ?? steps.count - 1) + 1)
    }

    var loginMode: OnboardingLoginMode {
        if isInvitedFlow { return .invitedPartner }
        return isReturningUser ? .returningUser : .saveProfile
    }

    /// Invite and returning-user sign-in can go back to welcome; post-paywall sign-in cannot.
    var canCancelSignIn: Bool { isInvitedFlow || isReturningUser }

    var anniversary: Date {
        get { draft.anniversary ?? Date() }
        set { draft.anniversary = newValue }
    }

    // MARK: Routing

    /// Resumes an interrupted flow: post-paywall sign-in, signed-in creator without Pro, or invited partner.
    func restoreFlow() {
        if defaults.bool(forKey: OnboardingFlowStorage.awaitingSignInAfterPaywall) {
            currentStep = .login
        } else if defaults.bool(forKey: OnboardingFlowStorage.postAuthCreatorFunnel) {
            setInvitedFlow(false)
            currentStep = .firstMemoryMap
        } else if isInvitedFlow {
            currentStep = .login
        }
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goToCommitmentEncouragement() {
        currentStep = .commitmentEncouragement
    }

    func goToPaywall() {
        currentStep = .paywall
    }

    /// "I have a code": invited partners skip the funnel and paywall and go straight to Sign-In.
    func startInvitedFlow() {
        setInvitedFlow(true)
        currentStep = .login
    }

    /// "I already have an account": existing users (e.g. after reinstall) skip straight to Sign-In.
    func startReturningUserSignIn() {
        isReturningUser = true
        currentStep = .login
    }

    /// Back from invite / returning-user Sign-In to the welcome step.
    func cancelSignIn() {
        setInvitedFlow(false)
        isReturningUser = false
        currentStep = .welcome
    }

    /// Paywall done: signed-in users finish now; everyone else signs in next so the draft can be saved.
    func paywallCompleted(appState: AppStateManager) async {
        if appState.currentUser != nil {
            await finish(appState: appState)
        } else {
            defaults.set(true, forKey: OnboardingFlowStorage.awaitingSignInAfterPaywall)
            currentStep = .login
        }
    }

    /// Called after Sign in with Apple succeeds (or when the login step appears already signed in).
    func signedIn(appState: AppStateManager) async {
        if isInvitedFlow {
            defaults.set(true, forKey: OnboardingFlowStorage.invitePairingEntryOnly)
        }
        await finish(appState: appState)
    }

    // MARK: First memory

    /// Stages the first memory on disk so it survives until sign-in, and keeps a preview for the next steps.
    func stageMemory(image: UIImage, note: String, coordinate: CLLocationCoordinate2D, appState: AppStateManager) {
        do {
            try appState.stageOnboardingMemory(image: image, note: note, coordinate: coordinate)
            memoryPreview = OnboardingMemoryPreview(image: image, note: note, coordinate: coordinate)
            showAddMemory = false
        } catch {
            memoryStageError = error.localizedDescription
        }
    }

    // MARK: Private

    /// Uploads the draft (no-op if signed out; AppStateManager retries after the next sign-in) and ends onboarding.
    private func finish(appState: AppStateManager) async {
        guard !isFinishing, !isComplete else { return }
        isFinishing = true
        defer { isFinishing = false }

        await appState.applyOnboardingDraftIfNeeded()

        defaults.set(false, forKey: OnboardingFlowStorage.awaitingSignInAfterPaywall)
        defaults.set(false, forKey: OnboardingFlowStorage.postAuthCreatorFunnel)
        setInvitedFlow(false)
        isComplete = true
    }

    private func setInvitedFlow(_ invited: Bool) {
        isInvitedFlow = invited
        defaults.set(invited, forKey: OnboardingFlowStorage.isInvitedPartner)
    }
}
