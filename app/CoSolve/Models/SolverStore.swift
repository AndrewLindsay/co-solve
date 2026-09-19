import Foundation
import SwiftUI

@MainActor
final class SolverStore: ObservableObject {
    @Published var gameMode: WordGameMode = .sixLetter

    @Published var currentGuess = ""
    @Published var tileStates = Array(repeating: TileState.grey, count: 6)
    @Published var history: [Guess] = []

    @Published var pattern = ""
    @Published var requiredLetters = ""
    @Published var excludedLetters = ""

    @Published var allWords: [String] = []
    @Published var candidates: [String] = []
    @Published var recommendations: [Recommendation] = []
    @Published var frequencies: [String: FrequencyRecord] = [:]
    @Published var downloadedDictionarySources = Set<DictionaryService.Source>()

    @Published var informationWeight = 0.70
    @Published var status = "Loading word lists…"
    @Published var isBusy = false
    @Published var errorMessage: String?

    var wordLength: Int { gameMode.wordLength }

    init(gameMode: WordGameMode = .sixLetter, shouldLoadInitialData: Bool = true) {
        self.gameMode = gameMode
        self.tileStates = Array(repeating: .grey, count: gameMode.wordLength)

        if shouldLoadInitialData {
            Task { await loadInitialData() }
        } else {
            status = "Preview data"
        }
    }

    func changeGameMode(to newMode: WordGameMode) {
        guard newMode != gameMode else { return }
        gameMode = newMode
        clearPuzzleState()
        allWords = []
        candidates = []
        recommendations = []
        frequencies = [:]
        status = "Loading cached \(wordLength)-letter data…"

        let requestedMode = newMode
        Task {
            let words = await DictionaryService.shared.cachedWords(wordLength: requestedMode.wordLength)
            let frequencyData = await FrequencyService.shared.cached(wordLength: requestedMode.wordLength)
            let downloadedSources = await DictionaryService.shared.cachedSources(wordLength: requestedMode.wordLength)
            guard gameMode == requestedMode else { return }
            allWords = words
            frequencies = frequencyData
            downloadedDictionarySources = downloadedSources
            applyFilters()
            if words.isEmpty {
                status = "No cached \(wordLength)-letter dictionary. Use Download Word List to add one."
            } else if frequencyData.isEmpty {
                status += " Commonness data has not been downloaded for \(wordLength)-letter words yet."
            }
        }
    }

    func addGuess() {
        let normalized = currentGuess.lowercased().filter { $0.isLetter }
        guard normalized.count == wordLength else {
            errorMessage = "Enter exactly \(wordLength) letters."
            return
        }
        history.append(Guess(word: normalized, feedback: tileStates))
        let summary = WordleSolver.summarize(history: history, wordLength: wordLength)
        pattern = summary.pattern
        requiredLetters = summary.required
        excludedLetters = summary.excluded
        currentGuess = ""
        tileStates = Array(repeating: .grey, count: wordLength)
        applyFilters()
    }

    func removeHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        let summary = WordleSolver.summarize(history: history, wordLength: wordLength)
        pattern = summary.pattern
        requiredLetters = summary.required
        excludedLetters = summary.excluded
        applyFilters()
    }

    func undoLastGuess() {
        guard !history.isEmpty else { return }

        history.removeLast()

        // Rebuild the derived constraints from the remaining guess history.
        // This makes repeated Undo operations return the solver to each
        // previous puzzle state in sequence.
        let summary = WordleSolver.summarize(history: history, wordLength: wordLength)
        pattern = summary.pattern
        requiredLetters = summary.required
        excludedLetters = summary.excluded

        currentGuess = ""
        tileStates = Array(repeating: .grey, count: wordLength)
        recommendations = []
        applyFilters()
    }

    func reset() {
        clearPuzzleState()
        applyFilters()
    }

    func useSuggestedWord(_ word: String) {
        currentGuess = String(word.prefix(wordLength)).uppercased()
        tileStates = Array(repeating: .grey, count: wordLength)
    }

    func applyFilters() {
        candidates = allWords.filter {
            WordleSolver.matchesHistory($0, history: history) &&
            WordleSolver.matchesDirectConstraints(
                $0,
                pattern: pattern,
                requiredLetters: requiredLetters,
                excludedLetters: excludedLetters,
                wordLength: wordLength
            )
        }
        recommendations = []
        status = "\(candidates.count) candidate(s) from \(allWords.count) \(wordLength)-letter words."
    }

    func recommend() {
        isBusy = true
        status = "Ranking \(candidates.count) candidates…"
        let candidates = candidates
        let frequencies = frequencies
        let weight = informationWeight

        Task.detached(priority: .userInitiated) {
            let result = RecommendationEngine.rank(
                candidates: candidates,
                frequencies: frequencies,
                informationWeight: weight
            )
            await MainActor.run {
                self.recommendations = Array(result.prefix(20))
                self.isBusy = false
                self.status = result.isEmpty ? "No candidates remain." : "Best next guess: \(result[0].word.uppercased())"
            }
        }
    }

    func downloadDictionary(_ source: DictionaryService.Source) {
        isBusy = true
        let requestedMode = gameMode
        status = "Downloading \(source.rawValue.lowercased()) for \(requestedMode.wordLength)-letter mode…"
        Task {
            do {
                let words = try await DictionaryService.shared.download(source, wordLength: requestedMode.wordLength)
                guard gameMode == requestedMode else {
                    isBusy = false
                    return
                }
                allWords = words
                downloadedDictionarySources = await DictionaryService.shared.cachedSources(wordLength: requestedMode.wordLength)
                applyFilters()
                status = "Loaded \(allWords.count) \(wordLength)-letter words."
            } catch {
                errorMessage = "Dictionary download failed: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func downloadFrequencyData() {
        isBusy = true
        let requestedMode = gameMode
        status = "Downloading commonness data for \(requestedMode.wordLength)-letter words…"
        Task {
            do {
                let data = try await FrequencyService.shared.download(wordLength: requestedMode.wordLength)
                guard gameMode == requestedMode else {
                    isBusy = false
                    return
                }
                frequencies = data
                status = "Commonness data available for \(frequencies.count) \(wordLength)-letter words."
            } catch {
                errorMessage = "Commonness download failed: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func commonness(for word: String) -> Double {
        RecommendationEngine.commonness100(zipf: frequencies[word]?.effectiveZipf)
    }

    func zipf(for word: String) -> Double? {
        frequencies[word]?.effectiveZipf
    }

    func hasFrequency(for word: String) -> Bool {
        frequencies[word]?.hasFrequency ?? false
    }

    private func clearPuzzleState() {
        currentGuess = ""
        tileStates = Array(repeating: .grey, count: wordLength)
        history = []
        pattern = ""
        requiredLetters = ""
        excludedLetters = ""
        recommendations = []
    }

    private func loadInitialData() async {
        let mode = gameMode
        allWords = await DictionaryService.shared.cachedWords(wordLength: mode.wordLength)
        frequencies = await FrequencyService.shared.cached(wordLength: mode.wordLength)
        downloadedDictionarySources = await DictionaryService.shared.cachedSources(wordLength: mode.wordLength)
        applyFilters()
        if frequencies.isEmpty {
            status += " Commonness data has not been downloaded yet."
        }
    }
}
