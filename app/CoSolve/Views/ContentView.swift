import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SolverStore
    #if os(iOS)
    @EnvironmentObject var consentManager: GoogleMobileAdsConsentManager
    @State private var showPrivacyAndAbout = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    GuessEntryView()
                    ConstraintsView()
                    actions
                    RecommendationView()
                    CandidateListView()

                    Text(store.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Co-Solve")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button { showPrivacyAndAbout = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About and Privacy")
                }
                #endif
                ToolbarItem {
                    Menu {
                        Picker("Puzzle Type", selection: gameModeBinding) {
                            ForEach(WordGameMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    } label: {
                        Label(store.gameMode.shortTitle, systemImage: "character.cursor.ibeam")
                    }
                    .help("Switch between 5-letter Wordle and 6-letter mode")
                }
            }

            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif

            .alert("Word Solver", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    store.errorMessage = nil
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if consentManager.canRequestAds {
                CoSolveBanner()
            }
        }
        .sheet(isPresented: $showPrivacyAndAbout) {
            PrivacyAndAboutView()
                .environmentObject(consentManager)
        }
        #endif

        #if os(macOS)
        .frame(minWidth: 850, minHeight: 650)
        #endif
    }

    private var gameModeBinding: Binding<WordGameMode> {
        Binding(
            get: { store.gameMode },
            set: { store.changeGameMode(to: $0) }
        )
    }

    private var header: some View {
        Text("Every recommendation is drawn only from the remaining valid answer pool.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        downloadMenu
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downloadMenu: some View {
        Menu("Download \(store.wordLength)-Letter Word List") {
            Button(dictionaryMenuTitle("Common Words", source: .common)) {
                store.downloadDictionary(.common)
            }

            Button(dictionaryMenuTitle("Comprehensive Dictionary", source: .comprehensive)) {
                store.downloadDictionary(.comprehensive)
            }
        }
        .disabled(store.isBusy)
        .buttonStyle(.bordered)
    }

    private func dictionaryMenuTitle(_ title: String, source: DictionaryService.Source) -> String {
        store.downloadedDictionarySources.contains(source) ? "\(title) ✓" : title
    }
}

#if os(iOS)
@MainActor
private func makeCoSolvePreviewStore(
    mode: WordGameMode,
    populated: Bool = false,
    downloadsComplete: Bool = false
) -> SolverStore {
    let store = SolverStore(gameMode: mode, shouldLoadInitialData: false)

    if downloadsComplete {
        store.downloadedDictionarySources = [.common, .comprehensive]
    }

    switch mode {
    case .fiveLetter:
        store.allWords = ["crane", "share", "stare", "store", "score", "shore"]
        store.candidates = store.allWords
        store.frequencies = [
            "crane": FrequencyRecord(primaryZipf: 4.20, subtlexZipf: 4.10, subtlexFrequencyPerMillion: 12.6),
            "share": FrequencyRecord(primaryZipf: 5.05, subtlexZipf: 5.12, subtlexFrequencyPerMillion: 132.0),
            "stare": FrequencyRecord(primaryZipf: 4.08, subtlexZipf: 4.01, subtlexFrequencyPerMillion: 10.2)
        ]

        if populated {
            store.history = [
                Guess(word: "arise", feedback: [.grey, .grey, .yellow, .grey, .green])
            ]
            store.pattern = "----E"
            store.requiredLetters = "IE"
            store.excludedLetters = "ARS"
            store.currentGuess = "CHIME"
            store.tileStates = [.grey, .yellow, .grey, .grey, .green]
            store.candidates = ["chime", "while", "quite", "guide"]
            store.recommendations = [
                Recommendation(word: "chime", combinedScore: 0.86, informationBits: 3.42, zipf: 4.16, commonness: 61, expectedRemaining: 2.1, worstCase: 5),
                Recommendation(word: "while", combinedScore: 0.79, informationBits: 3.11, zipf: 5.31, commonness: 80, expectedRemaining: 2.5, worstCase: 6)
            ]
        }

    case .sixLetter:
        store.allWords = ["friend", "orange", "planet", "stream", "chance", "bridge"]
        store.candidates = store.allWords
        store.frequencies = [
            "friend": FrequencyRecord(primaryZipf: 5.45, subtlexZipf: 5.51, subtlexFrequencyPerMillion: 323.0),
            "orange": FrequencyRecord(primaryZipf: 4.62, subtlexZipf: 4.70, subtlexFrequencyPerMillion: 50.1),
            "planet": FrequencyRecord(primaryZipf: 4.38, subtlexZipf: 4.30, subtlexFrequencyPerMillion: 20.0)
        ]

        if populated {
            store.history = [
                Guess(word: "stream", feedback: [.grey, .green, .grey, .yellow, .grey, .grey]),
                Guess(word: "planet", feedback: [.grey, .grey, .yellow, .grey, .green, .grey])
            ]
            store.pattern = "-T--E-"
            store.requiredLetters = "EIT"
            store.excludedLetters = "ALMNPRS"
            store.currentGuess = "BITTEN"
            store.tileStates = [.grey, .green, .yellow, .grey, .green, .grey]
            store.candidates = ["bitten", "kitten", "citied", "tithed"]
            store.recommendations = [
                Recommendation(word: "bitten", combinedScore: 0.89, informationBits: 3.76, zipf: 4.18, commonness: 62, expectedRemaining: 1.9, worstCase: 4),
                Recommendation(word: "kitten", combinedScore: 0.83, informationBits: 3.55, zipf: 4.37, commonness: 66, expectedRemaining: 2.0, worstCase: 5)
            ]
        }
    }

    store.status = populated
        ? "Preview: puzzle in progress"
        : "Preview: ready for a new puzzle"
    return store
}

#Preview("Small iPhone • 5 Letters") {
    ContentView()
        .environmentObject(makeCoSolvePreviewStore(mode: .fiveLetter))
        .environmentObject(GoogleMobileAdsConsentManager())
        .frame(width: 375, height: 667)
}

#Preview("Standard iPhone • 6 Letters") {
    ContentView()
        .environmentObject(makeCoSolvePreviewStore(mode: .sixLetter, populated: true))
        .environmentObject(GoogleMobileAdsConsentManager())
        .frame(width: 393, height: 852)
}

#Preview("Large iPhone • Downloads Ready") {
    ContentView()
        .environmentObject(makeCoSolvePreviewStore(
            mode: .sixLetter,
            populated: true,
            downloadsComplete: true
        ))
        .frame(width: 430, height: 932)
}
#endif

