#if os(iOS)
import Foundation
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class GoogleMobileAdsConsentManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var statusMessage = "Checking privacy choices…"

#if DEBUG
    @Published var debugMode: AdConfiguration.ConsentDebugMode = AdConfiguration.consentDebugMode
    @Published private(set) var debugTestRunning = false
#endif

    private var didStartAds = false

    func gatherConsentAndStartAds() async {
        // Build 4 hard gate. UMP and Google Mobile Ads must never be invoked
        // while Apple's ATT state is still notDetermined.
        guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else {
            canRequestAds = false
            statusMessage = "Advertising is waiting for tracking permission."
            print("[Privacy] BLOCKED: UMP was not started because ATT is still notDetermined")
            return
        }

        print("[Privacy] ATT resolved before UMP: \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")

#if DEBUG
        await runConsentFlow(mode: debugMode, resetFirst: AdConfiguration.resetConsentOnDebugLaunch)
#else
        await runConsentFlow()
#endif
    }

#if DEBUG
    /// Resets UMP consent state and immediately repeats the consent request using
    /// the region selected in the About & Privacy diagnostic controls.
    func resetConsentAndTestAgain() async {
        guard !debugTestRunning else { return }
        guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else {
            statusMessage = "Resolve tracking permission before testing advertising privacy."
            print("[Privacy] BLOCKED: UMP debug test requested while ATT is still notDetermined")
            return
        }

        debugTestRunning = true
        defer { debugTestRunning = false }

        statusMessage = "Resetting consent and testing \(debugMode.displayName)…"
        await runConsentFlow(mode: debugMode, resetFirst: true)
    }

    private func runConsentFlow(
        mode: AdConfiguration.ConsentDebugMode,
        resetFirst: Bool
    ) async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        print("[UMP] ===== Co-Solve UMP Debug Start =====")
        print("[UMP] ATT entering UMP: \(ATTrackingManager.trackingAuthorizationStatus.rawValue)")
        print("[UMP] Bundle ID: \(Bundle.main.bundleIdentifier ?? "<missing>")")
        print("[UMP] GADApplicationIdentifier: \(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? "<missing>")")

        if resetFirst {
            ConsentInformation.shared.reset()
            print("[UMP] Consent state reset for this Debug test")
        }

        let debugSettings = DebugSettings()
        var attachDebugSettings = false

#if targetEnvironment(simulator)
        print("[UMP] Environment: iOS Simulator")
        print("[UMP] Simulator is a UMP test device by default; no hashed ID is required")
#else
        print("[UMP] Environment: physical iOS device")
#endif

        if let identifier = AdConfiguration.consentTestDeviceIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !identifier.isEmpty {
            debugSettings.testDeviceIdentifiers = [identifier]
            attachDebugSettings = true
            print("[UMP] Explicit hashed test-device identifier attached: \(identifier)")
        } else {
#if !targetEnvironment(simulator)
            print("[UMP] No hashed physical-device ID is configured")
#endif
        }

        switch mode {
        case .discoverDeviceID:
            print("[UMP] Test mode: DISCOVER DEVICE ID")
            if let identifier = AdConfiguration.consentTestDeviceIdentifier,
               !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                attachDebugSettings = true
            }

        case .eea:
            debugSettings.geography = .EEA
            attachDebugSettings = true
            print("[UMP] Test mode: FORCE EEA")
#if !targetEnvironment(simulator)
            if AdConfiguration.consentTestDeviceIdentifier == nil {
                print("[UMP] WARNING: forced geography on a physical iPhone requires its hashed UMP test-device ID")
                print("[UMP] Select Discover Device ID, run once, copy the <UMP SDK> ID, then configure it in AdConfiguration.swift")
            }
#endif

        case .regulatedUSState:
            debugSettings.geography = .regulatedUSState
            attachDebugSettings = true
            print("[UMP] Test mode: FORCE REGULATED US STATE")
#if !targetEnvironment(simulator)
            if AdConfiguration.consentTestDeviceIdentifier == nil {
                print("[UMP] WARNING: forced geography on a physical iPhone requires its hashed UMP test-device ID")
            }
#endif

        case .other:
            debugSettings.geography = .other
            attachDebugSettings = true
            print("[UMP] Test mode: FORCE OTHER")

        case .disabled:
            print("[UMP] Test mode: NORMAL / REAL GEOGRAPHY")
        }

        if attachDebugSettings {
            parameters.debugSettings = debugSettings
            print("[UMP] DebugSettings attached to request")
        } else {
            print("[UMP] No DebugSettings attached to request")
        }

        print("[UMP] Before update: consentStatus=\(ConsentInformation.shared.consentStatus.rawValue), canRequestAds=\(ConsentInformation.shared.canRequestAds), privacyOptions=\(ConsentInformation.shared.privacyOptionsRequirementStatus.rawValue)")

        await performConsentRequest(
            with: parameters,
            eeaTestRequested: mode == .eea,
            selectedTestRegion: mode.displayName
        )
    }
#else
    private func runConsentFlow() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        await performConsentRequest(
            with: parameters,
            eeaTestRequested: false,
            selectedTestRegion: nil
        )
    }
#endif

    private func performConsentRequest(
        with parameters: RequestParameters,
        eeaTestRequested: Bool,
        selectedTestRegion: String?
    ) async {
        // Defence in depth: even an accidental future call into this method
        // cannot contact UMP until ATT has a resolved state.
        guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else {
            canRequestAds = false
            statusMessage = "Advertising is waiting for tracking permission."
            print("[Privacy] BLOCKED: performConsentRequest called while ATT is notDetermined")
            return
        }

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            print("[UMP] Consent info update succeeded")
            print("[UMP] After update: consentStatus=\(ConsentInformation.shared.consentStatus.rawValue), canRequestAds=\(ConsentInformation.shared.canRequestAds), privacyOptions=\(ConsentInformation.shared.privacyOptionsRequirementStatus.rawValue)")

#if DEBUG
            if ConsentInformation.shared.consentStatus == .notRequired,
               eeaTestRequested {
                print("[UMP] NOTE: EEA was requested but UMP returned NOT REQUIRED")
            }
#endif

            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            print("[UMP] loadAndPresentIfRequired completed")
        } catch {
            statusMessage = "Privacy setup: \(error.localizedDescription)"
            print("[UMP] ERROR: \(error.localizedDescription)")
        }

        refreshState()
        startAdsIfAllowed()

#if DEBUG
        if let selectedTestRegion {
            print("[UMP] Selected test region: \(selectedTestRegion)")
        }
        print("[UMP] ===== Co-Solve UMP Debug End =====")
#endif
    }

    func presentPrivacyOptions() async {
        guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else {
            statusMessage = "Resolve tracking permission before changing advertising privacy choices."
            print("[Privacy] BLOCKED: privacy options requested while ATT is notDetermined")
            return
        }

        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            statusMessage = "Privacy choices: \(error.localizedDescription)"
            print("[UMP] Privacy options ERROR: \(error.localizedDescription)")
        }
        refreshState()
        startAdsIfAllowed()
    }

#if DEBUG
    func presentAdInspector() async {
        guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else {
            statusMessage = "Resolve tracking permission before opening Ad Inspector."
            print("[AdMob] BLOCKED: Ad Inspector requested while ATT is notDetermined")
            return
        }

        print("[AdMob] Opening Ad Inspector…")
        do {
            try await MobileAds.shared.presentAdInspector(from: nil)
            print("[AdMob] Ad Inspector closed")
        } catch {
            statusMessage = "Ad Inspector: \(error.localizedDescription)"
            print("[AdMob] Ad Inspector ERROR: \(error.localizedDescription)")
        }
    }
#endif

    private func refreshState() {
        let umpAllowsAds = ConsentInformation.shared.canRequestAds
        let attStatus = ATTrackingManager.trackingAuthorizationStatus
        let attResolved = attStatus != .notDetermined

        // A denial/restriction of ATT does NOT disable ads. It prevents use of
        // the IDFA. Google Mobile Ads can still request ads without the IDFA.
        canRequestAds = umpAllowsAds && attResolved
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        statusMessage = canRequestAds
            ? "Advertising privacy choices are up to date."
            : "Advertising is waiting for privacy choices."

        print("[Privacy] Final state: canRequestAds=\(canRequestAds), UMP=\(umpAllowsAds), ATT=\(attStatus.rawValue), privacyOptionsRequired=\(privacyOptionsRequired), consentStatus=\(ConsentInformation.shared.consentStatus.rawValue)")
    }

    private func startAdsIfAllowed() {
        let attStatus = ATTrackingManager.trackingAuthorizationStatus
        guard attStatus != .notDetermined else {
            canRequestAds = false
            print("[AdMob] BLOCKED: SDK cannot start while ATT is notDetermined")
            return
        }

        guard canRequestAds, !didStartAds else {
            if !canRequestAds {
                print("[AdMob] SDK not started: consent does not yet permit ad requests")
            }
            return
        }
        didStartAds = true
        MobileAds.shared.start()
        print("[AdMob] Mobile Ads SDK started after ATT=\(attStatus.rawValue)")
    }
}
#endif
