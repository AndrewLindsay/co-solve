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

        // Apple requires the system ATT decision before any advertising SDK
        // request that could use data for tracking. UMP consent and ATT are
        // separate permissions, so complete UMP first, then ATT, then ads.
        await requestTrackingAuthorizationIfNeeded()
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

    private func requestTrackingAuthorizationIfNeeded() async {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        print("[ATT] Current status: \(currentStatus.rawValue)")

        guard currentStatus == .notDetermined else {
            print("[ATT] Permission already decided; no prompt required")
            return
        }

        // This is Apple's system permission dialog. It is intentionally shown
        // only after any required UMP privacy form has finished.
        let newStatus = await ATTrackingManager.requestTrackingAuthorization()
        print("[ATT] Request completed with status: \(newStatus.rawValue)")
    }

    private func refreshState() {
        let umpAllowsAds = ConsentInformation.shared.canRequestAds
        let attResolved = ATTrackingManager.trackingAuthorizationStatus != .notDetermined

        // A denial/restriction of ATT does NOT disable ads. It prevents use of
        // the IDFA. Google Mobile Ads can still request ads without the IDFA.
        canRequestAds = umpAllowsAds && attResolved
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        statusMessage = canRequestAds
            ? "Advertising privacy choices are up to date."
            : "Advertising is waiting for privacy choices."

        print("[Privacy] Final state: canRequestAds=\(canRequestAds), UMP=\(umpAllowsAds), ATT=\(ATTrackingManager.trackingAuthorizationStatus.rawValue), privacyOptionsRequired=\(privacyOptionsRequired), consentStatus=\(ConsentInformation.shared.consentStatus.rawValue)")
    }

    private func startAdsIfAllowed() {
        guard canRequestAds, !didStartAds else {
            if !canRequestAds {
                print("[AdMob] SDK not started: consent does not yet permit ad requests")
            }
            return
        }
        didStartAds = true
        MobileAds.shared.start()
        print("[AdMob] Mobile Ads SDK started")
    }
}
#endif
