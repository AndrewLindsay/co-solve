import Foundation

enum WordGameMode: Int, CaseIterable, Identifiable, Hashable {
    case fiveLetter = 5
    case sixLetter = 6

    var id: Int { rawValue }
    var wordLength: Int { rawValue }

    var title: String {
        switch self {
        case .fiveLetter: return "Wordle – 5 Letters"
        case .sixLetter: return "Six-Letter – 6 Letters"
        }
    }

    var shortTitle: String { "\(wordLength)-Letter" }

    var guessPlaceholder: String { "\(wordLength)-letter guess" }

    var patternExample: String {
        String(repeating: "-", count: max(0, wordLength - 2)) + "R-"
    }
}

enum TileState: Int, Codable, CaseIterable, Hashable {
    case grey = 0
    case yellow = 1
    case green = 2

    var next: TileState {
        switch self {
        case .grey: return .yellow
        case .yellow: return .green
        case .green: return .grey
        }
    }

    var label: String {
        switch self {
        case .grey: return "Grey"
        case .yellow: return "Yellow"
        case .green: return "Green"
        }
    }
}

struct Guess: Identifiable, Codable, Hashable {
    let id: UUID
    let word: String
    let feedback: [TileState]

    init(id: UUID = UUID(), word: String, feedback: [TileState]) {
        self.id = id
        self.word = word.lowercased()
        self.feedback = feedback
    }
}

struct FrequencyRecord: Codable, Hashable {
    /// Primary/comprehensive Zipf value, when available.
    let primaryZipf: Double?

    /// SUBTLEX-US Zipf value, when available.
    let subtlexZipf: Double?

    /// SUBTLEX frequency-per-million retained for transparency/debugging.
    let subtlexFrequencyPerMillion: Double?

    var hasFrequency: Bool {
        primaryZipf != nil || subtlexZipf != nil
    }

    /// Effective score used by ranking. If both sources exist, prefer the
    /// comprehensive source but retain a conversational SUBTLEX contribution.
    var effectiveZipf: Double? {
        switch (primaryZipf, subtlexZipf) {
        case let (.some(primary), .some(subtlex)):
            return 0.75 * primary + 0.25 * subtlex
        case let (.some(primary), nil):
            return primary
        case let (nil, .some(subtlex)):
            return subtlex
        case (nil, nil):
            return nil
        }
    }
}

struct Recommendation: Identifiable, Hashable {
    var id: String { word }
    let word: String
    let combinedScore: Double
    let informationBits: Double
    let zipf: Double?
    let commonness: Double
    let expectedRemaining: Double?
    let worstCase: Int?
}
