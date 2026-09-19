import Foundation

struct RecommendationEngine {
    /// Small explicit preference for candidates that have measured frequency data.
    /// This affects ranking only; it never removes an answer from the candidate pool.
    static let knownFrequencyBonus = 0.06

    static func rank(
        candidates: [String],
        frequencies: [String: FrequencyRecord],
        informationWeight: Double
    ) -> [Recommendation] {
        guard !candidates.isEmpty else { return [] }
        if candidates.count == 1 {
            let word = candidates[0]
            let zipf = frequencies[word]?.effectiveZipf
            return [Recommendation(
                word: word,
                combinedScore: 1,
                informationBits: 0,
                zipf: zipf,
                commonness: commonness100(zipf: zipf),
                expectedRemaining: 1,
                worstCase: 1
            )]
        }

        let infoWeight = min(max(informationWeight, 0), 1)
        let commonWeight = 1 - infoWeight

        if candidates.count > 3000 {
            return fastRank(
                candidates: candidates,
                frequencies: frequencies,
                informationWeight: infoWeight,
                commonWeight: commonWeight
            )
        }

        let n = Double(candidates.count)
        let maxEntropy = log2(n)
        var output: [Recommendation] = []
        output.reserveCapacity(candidates.count)

        for guess in candidates {
            var buckets: [[TileState]: Int] = [:]
            for answer in candidates {
                let key = WordleSolver.feedback(answer: answer, guess: guess)
                buckets[key, default: 0] += 1
            }

            var entropy = 0.0
            var expectedRemaining = 0.0
            var worstCase = 0

            for count in buckets.values {
                let p = Double(count) / n
                entropy -= p * log2(p)
                expectedRemaining += p * Double(count)
                worstCase = max(worstCase, count)
            }

            let record = frequencies[guess]
            let zipf = record?.effectiveZipf
            let commonness = commonness100(zipf: zipf)
            let infoNorm = maxEntropy > 0 ? entropy / maxEntropy : 0
            var combined = infoWeight * infoNorm + commonWeight * (commonness / 100)
            if record?.hasFrequency == true {
                combined += knownFrequencyBonus
            }

            output.append(Recommendation(
                word: guess,
                combinedScore: combined,
                informationBits: entropy,
                zipf: zipf,
                commonness: commonness,
                expectedRemaining: expectedRemaining,
                worstCase: worstCase
            ))
        }

        return output.sorted {
            if $0.combinedScore != $1.combinedScore { return $0.combinedScore > $1.combinedScore }
            if $0.informationBits != $1.informationBits { return $0.informationBits > $1.informationBits }
            return $0.word < $1.word
        }
    }

    static func commonness100(zipf: Double?) -> Double {
        guard let zipf, zipf > 0 else { return 0 }
        return min(max((zipf - 1) / 6 * 100, 0), 100)
    }

    private static func fastRank(
        candidates: [String],
        frequencies: [String: FrequencyRecord],
        informationWeight: Double,
        commonWeight: Double
    ) -> [Recommendation] {
        let wordLength = candidates.first?.count ?? 0
        guard wordLength > 0 else { return [] }
        var positional = Array(repeating: [Character: Int](), count: wordLength)
        var overall: [Character: Int] = [:]

        for word in candidates {
            let chars = Array(word)
            for i in 0..<min(chars.count, wordLength) {
                positional[i][chars[i], default: 0] += 1
            }
            for ch in Set(chars) { overall[ch, default: 0] += 1 }
        }

        var structural: [(String, Double)] = []
        var maxScore = 0.0
        for word in candidates {
            let chars = Array(word)
            var seen = Set<Character>()
            var score = 0.0
            for i in 0..<min(chars.count, wordLength) {
                let ch = chars[i]
                score += Double(positional[i][ch, default: 0])
                if seen.insert(ch).inserted {
                    score += Double(overall[ch, default: 0])
                }
            }
            maxScore = max(maxScore, score)
            structural.append((word, score))
        }

        return structural.map { word, score in
            let record = frequencies[word]
            let zipf = record?.effectiveZipf
            let commonness = commonness100(zipf: zipf)
            let structuralNorm = maxScore > 0 ? score / maxScore : 0
            var combined = informationWeight * structuralNorm + commonWeight * (commonness / 100)
            if record?.hasFrequency == true {
                combined += knownFrequencyBonus
            }
            return Recommendation(
                word: word,
                combinedScore: combined,
                informationBits: 0,
                zipf: zipf,
                commonness: commonness,
                expectedRemaining: nil,
                worstCase: nil
            )
        }.sorted {
            if $0.combinedScore != $1.combinedScore { return $0.combinedScore > $1.combinedScore }
            return $0.word < $1.word
        }
    }
}
