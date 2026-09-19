# Co-Solve v1.40

## Release-preparation privacy cleanup
- Release builds use the real AdMob app and banner IDs and the normal UMP geography flow.
- All consent-region forcing, consent reset controls, Ad Inspector access, and UMP test-device configuration remain DEBUG-only.
- Debug now starts in **Normal / Real Geography** and does **not** automatically reset consent.
- The DEBUG banner uses Google's fixed-size 320×50 test banner ID to match the current `AdSizeBanner` view.
- The public app version remains **1.0.0 (2)** for the planned Build 2 submission.
- The EEA consent path has been verified successfully on a registered physical UMP test device.

Based on the working v1.31 renamed/preview baseline.

Changes:
- Version 1.0.0, Build 2.
- `ITSAppUsesNonExemptEncryption = NO` for the current exempt/OS-provided encryption use.
- Google Mobile Ads + User Messaging Platform through Swift Package Manager.
- Google's official sample AdMob app ID and iOS test banner unit ID only.
- Bottom adaptive test banner shown only after UMP says ads may be requested.
- About & Privacy screen with Privacy Choices when required.
- Existing Co-Solve Canvas preview fixes retained.
- Removed stray zero-byte Untitled.swift.

Before App Store release, replace test IDs with production AdMob IDs, configure Privacy & Messaging in AdMob, publish a privacy-policy URL, and complete App Store privacy disclosures.


## v1.39 privacy-test additions
- Added Google's current 50 SKAdNetwork identifiers to `CoSolveiOS-Info.plist`.
- Added DEBUG-only UMP geography forcing in `AdConfiguration.swift`.
- Default Debug geography is `.eea` and Debug launches reset UMP consent state so the published European message can be tested repeatedly.
- Added concise `[UMP]` and `[AdMob]` console diagnostics.
- Release builds do not compile the forced geography or consent reset code.


## v1.39 UMP diagnostic update
- Adds a clear Debug test mode: discover device ID, EEA, regulated US state, other, or disabled.
- Prints Bundle ID and GADApplicationIdentifier so the AdMob app identity can be verified from Xcode.
- Gives a specific warning when forced EEA still returns `notRequired`.
- Physical iPhone workflow can discover and then explicitly register the hashed UMP test-device ID.
- Simulator remains supported without a hashed ID because Google documents simulators as test devices by default.


## v1.39 UMP fix
The iOS Debug build now explicitly defines the Swift `DEBUG` compilation condition. Previous project settings used the Debug configuration and `-Onone`, but did not define `DEBUG`, so all `#if DEBUG` UMP geography/testing code was compiled out. v1.39 also uses the UMP 3.x `isTaggedForUnderAgeOfConsent` property name.


## v1.39
- Adds a DEBUG-only **Open Ad Inspector** button to **About & Privacy**.
- Uses Google Mobile Ads `MobileAds.shared.presentAdInspector(from: nil)` so the inspector can be opened directly from the app.
- Production/Release UI is unchanged because the button is enclosed in `#if DEBUG`.
- Use **Ad Inspector → Privacy** to inspect Google's GDPR/TCF state during forced-EEA UMP testing.