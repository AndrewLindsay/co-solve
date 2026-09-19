import SwiftUI

#if os(iOS)
struct PrivacyAndAboutView: View {
    @EnvironmentObject var consentManager: GoogleMobileAdsConsentManager
    @Environment(\.dismiss) private var dismiss

    private let privacyPolicyURL = URL(string: "https://andrewlindsay.github.io/co-solve/privacy.html")!

    var body: some View {
        NavigationStack {
            Form {
                Section("Co-Solve") {
                    LabeledContent("Version", value: "1.0.0 (2)")
                    Text("Co-Solve helps narrow and rank candidate words for five- and six-letter word puzzles.")
                }

                Section("Advertising & Privacy") {
#if DEBUG
                    Text("This development build uses Google's test banner advertising unit. Test ads do not generate advertising revenue.")
                        .foregroundStyle(.secondary)
#else
                    Text("Co-Solve uses Google AdMob to display a small banner advertisement.")
                        .foregroundStyle(.secondary)
#endif

                    Text(consentManager.statusMessage)
                        .foregroundStyle(.secondary)

                    if consentManager.privacyOptionsRequired {
                        Button("Privacy Choices") {
                            Task { await consentManager.presentPrivacyOptions() }
                        }
                    }

                    Link("Privacy Policy", destination: privacyPolicyURL)
                }

#if DEBUG
                Section("Privacy Test Region") {
                    Picker("Test Region", selection: $consentManager.debugMode) {
                        ForEach(AdConfiguration.ConsentDebugMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Button {
                        Task { await consentManager.resetConsentAndTestAgain() }
                    } label: {
                        if consentManager.debugTestRunning {
                            HStack {
                                ProgressView()
                                Text("Testing…")
                            }
                        } else {
                            Label("Reset Consent & Test Again", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(consentManager.debugTestRunning)

                    Button {
                        Task { await consentManager.presentAdInspector() }
                    } label: {
                        Label("Open Ad Inspector", systemImage: "wrench.and.screwdriver")
                    }
                    .disabled(consentManager.debugTestRunning)

                    Text("Debug only. Select a region, reset and test again, then open Ad Inspector → Privacy. Europe should report GDPR applies when Google's EEA override is being honoured.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
#endif
            }
            .navigationTitle("About & Privacy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
