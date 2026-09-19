# Co-Solve v1.40 — UMP testing guide

## Simulator — EEA test
1. Open `CoSolve/Ads/AdConfiguration.swift`.
2. Leave `consentDebugMode = .eea`.
3. On the simulator, `consentTestDeviceIdentifier` can remain `nil`. On a physical iPhone, explicitly register the UMP test-device identifier printed by the SDK before forcing EEA or a regulated US state.
4. Clean Build Folder and Run.
5. In the console, search for `[UMP]`.
6. Confirm the log says `Test mode: FORCE EEA` and `DebugSettings attached to request`.
7. If UMP returns `consentStatus=2` (`notRequired`), the code now prints an explanation. Check that the published European message has propagated and Co-Solve is selected for that message.

## Physical iPhone — discover the UMP test-device ID
1. Set `consentDebugMode = .discoverDeviceID`.
2. Run on the physical iPhone.
3. Search the Xcode console for `<UMP SDK>`.
4. Google should print a line similar to: `To enable debug mode for this device, set: UMPDebugSettings.testDeviceIdentifiers = @[HASH]`.
5. Copy only the HASH into `consentTestDeviceIdentifier`.
6. Change `consentDebugMode` back to `.eea` or `.regulatedUSState`.
7. Run again.

## US-state test
Set:
`static let consentDebugMode: ConsentDebugMode = .regulatedUSState`
Then clean/run again.

## Production
All of these test controls are inside `#if DEBUG`, so they are excluded from Release builds. Never call UMP `reset()` in production code.


### What v1.40 keeps for DEBUG diagnostics
The Xcode Debug configuration now contains `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`. This is essential because the UMP geography override and test diagnostics are enclosed in `#if DEBUG`. On launch, you should now see `[UMP] ===== Co-Solve UMP Debug Start =====`, `Test mode: FORCE EEA`, and `DebugSettings attached to request` before the consent update.


## v1.40 — Ad Inspector privacy check
1. Run the iOS app from Xcode in Debug on the simulator.
2. Tap the **ⓘ** button at the top left.
3. In **Advertising & Privacy**, tap **Open Ad Inspector**.
4. Open the inspector's **Privacy** section.
5. Check whether **GDPR applies** / GDPR applicability is reported for the session.
6. Send a screenshot of that Privacy screen for diagnosis.

The button is Debug-only and is not included in Release builds.
