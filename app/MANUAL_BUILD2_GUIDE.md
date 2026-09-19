# Co-Solve Build 2 / v1.40

Before archiving, select a **Release** archive configuration. The DEBUG-only privacy test region, consent reset, test-device ID and Ad Inspector controls are excluded from Release builds. Public version remains **1.0.0**, build **2**.

# Co-Solve v1.33 — Build 2 AdMob/UMP integration

This revision is based on v1.32 and is prepared for Build 2 testing.

- Version remains 1.0.0; build is 2.
- Bundle ID remains `com.andrewlindsay.cosolve`.
- `ITSAppUsesNonExemptEncryption` is `NO`.
- Google Mobile Ads and User Messaging Platform are Swift Package dependencies.
- The real Co-Solve AdMob application ID is stored in `CoSolveiOS-Info.plist`, which allows the published Co-Solve privacy messages to be retrieved.
- DEBUG builds use Google's official iOS anchored-adaptive test banner ID.
- RELEASE builds are configured for the Co-Solve production banner ID. Do not click live ads in a Release build.
- The About & Privacy screen links to the published Co-Solve privacy policy:
  `https://andrewlindsay.github.io/co-solve/privacy.html`
- UMP requests fresh consent information at launch, presents a required message, and only starts Mobile Ads when `canRequestAds` is true.
- A Privacy Choices button is shown when UMP reports that a privacy-options entry point is required.
- No App Tracking Transparency prompt is requested by this revision.

## First test

1. Open `CoSolveiOS.xcodeproj` (or `CoSolve.xcworkspace`).
2. Let Xcode resolve both Google Swift packages.
3. Select the CoSolveiOS scheme and an iPhone simulator.
4. Build and run the DEBUG configuration.
5. Confirm the solver launches normally and a banner is marked as a test ad.
6. Open About & Privacy and verify the Privacy Policy link.
7. Test on the physical iPhone after the simulator works.
8. Do not upload Build 2 until these checks pass.
