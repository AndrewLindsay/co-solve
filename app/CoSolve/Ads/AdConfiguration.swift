import Foundation

enum AdConfiguration {

    static let applicationID =
        "ca-app-pub-6456812152893790~2786706129"

    static let bannerUnitID: String = {
#if DEBUG
        // Google's official test banner ID.
        return "ca-app-pub-3940256099942544/2934735716"
#else
        // Co-Solve production banner.
        return "ca-app-pub-6456812152893790/1034992406"
#endif
    }()

#if DEBUG
    // UMP diagnostic modes. These controls do not exist in Release builds.
    enum ConsentDebugMode: String, CaseIterable, Identifiable {
        case eea
        case regulatedUSState
        case other
        case disabled
        case discoverDeviceID

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .eea: return "Europe (EEA)"
            case .regulatedUSState: return "Regulated US State"
            case .other: return "Other Region"
            case .disabled: return "Normal / Real Geography"
            case .discoverDeviceID: return "Discover Device ID"
            }
        }
    }

    // Initial selection shown in the debug UI.
    static let consentDebugMode: ConsentDebugMode = .disabled

    // Normal Debug launches preserve the current UMP state. Use the in-app
    // diagnostic button when an explicit reset is required.
    static let resetConsentOnDebugLaunch = false

    // PHYSICAL iPhone only:
    // 1. Select "Discover Device ID" in About & Privacy.
    // 2. Tap "Reset Consent & Test Again" and inspect the Xcode console.
    // 3. Paste the hashed <UMP SDK> identifier below.
    // 4. Select Europe or Regulated US State and test again.
    //
    // iOS Simulator: leave this nil.
    static let consentTestDeviceIdentifier: String? = nil
#endif
}
