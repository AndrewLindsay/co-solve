import Foundation

struct WordleSolver {
    static func feedback(answer: String, guess: String) -> [TileState] {
        let answerChars = Array(answer.lowercased())
        let guessChars = Array(guess.lowercased())
        let length = answerChars.count
        guard length > 0, guessChars.count == length else {
            return Array(repeating: .grey, count: max(length, guessChars.count))
        }

        var result = Array(repeating: TileState.grey, count: length)
        var remaining: [Character: Int] = [:]

        for i in 0..<length {
            if answerChars[i] == guessChars[i] {
                result[i] = .green
            } else {
                remaining[answerChars[i], default: 0] += 1
            }
        }

        for i in 0..<length where result[i] != .green {
            let ch = guessChars[i]
            if let count = remaining[ch], count > 0 {
                result[i] = .yellow
                remaining[ch] = count - 1
            }
        }

        return result
    }

    static func matchesHistory(_ word: String, history: [Guess]) -> Bool {
        for guess in history {
            if feedback(answer: word, guess: guess.word) != guess.feedback {
                return false
            }
        }
        return true
    }

    static func matchesDirectConstraints(
        _ word: String,
        pattern: String,
        requiredLetters: String,
        excludedLetters: String,
        wordLength: Int
    ) -> Bool {
        let chars = Array(word.lowercased())
        guard chars.count == wordLength else { return false }

        let normalizedPattern = pattern.isEmpty ? String(repeating: "-", count: wordLength) : pattern.lowercased()
        let p = Array(normalizedPattern)
        guard p.count == wordLength else { return false }

        for i in 0..<wordLength {
            let ch = p[i]
            if ch == "-" || ch == "_" || ch == "?" || ch == "." { continue }
            if chars[i] != ch { return false }
        }

        let wordCounts = counts(in: chars)
        let requiredCounts = counts(in: Array(requiredLetters.lowercased().filter { $0.isLetter }))
        for (letter, count) in requiredCounts where wordCounts[letter, default: 0] < count {
            return false
        }

        for letter in Set(excludedLetters.lowercased().filter { $0.isLetter }) {
            if wordCounts[letter, default: 0] > 0 { return false }
        }

        return true
    }

    static func summarize(history: [Guess], wordLength: Int) -> (pattern: String, required: String, excluded: String) {
        var pattern = Array(repeating: Character("-"), count: wordLength)
        var minCounts: [Character: Int] = [:]
        var absent = Set<Character>()
        var positive = Set<Character>()

        for guess in history {
            let letters = Array(guess.word)
            var positiveThisGuess: [Character: Int] = [:]

            for i in 0..<min(wordLength, min(letters.count, guess.feedback.count)) {
                let letter = letters[i]
                let state = guess.feedback[i]
                if state == .green {
                    pattern[i] = Character(letter.uppercased())
                }
                if state == .green || state == .yellow {
                    positiveThisGuess[letter, default: 0] += 1
                    positive.insert(letter)
                }
            }

            for (letter, count) in positiveThisGuess {
                minCounts[letter] = max(minCounts[letter, default: 0], count)
            }

            for letter in Set(letters) {
                var states: [TileState] = []
                for i in 0..<min(letters.count, guess.feedback.count) where letters[i] == letter {
                    states.append(guess.feedback[i])
                }
                if !states.isEmpty && states.allSatisfy({ $0 == .grey }) {
                    absent.insert(letter)
                }
            }
        }

        absent.subtract(positive)

        let required = minCounts.keys.sorted().map { key in
            String(repeating: String(key).uppercased(), count: minCounts[key, default: 0])
        }.joined()
        let excluded = absent.sorted().map { String($0).uppercased() }.joined()

        return (String(pattern), required, excluded)
    }

    private static func counts(in chars: [Character]) -> [Character: Int] {
        var result: [Character: Int] = [:]
        for ch in chars { result[ch, default: 0] += 1 }
        return result
    }
}
