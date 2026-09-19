import Foundation

actor FrequencyService {
    static let shared = FrequencyService()

    // Current online source: SUBTLEX-US. The same source is filtered independently
    // for the active 5-letter or 6-letter puzzle mode.
    private let subtlexURL = URL(string: "https://raw.githubusercontent.com/AusterweilLab/snafu-py/master/frequency/subtlex-us.csv")!

    func cached(wordLength: Int) -> [String: FrequencyRecord] {
        let current = cacheURL(wordLength: wordLength)
        if let text = try? String(contentsOf: current, encoding: .utf8) {
            return parseCache(text, wordLength: wordLength)
        }

        // v1.22 compatibility: retain the old six-letter frequency cache.
        if wordLength == 6,
           let text = try? String(contentsOf: legacyCacheURL, encoding: .utf8) {
            return parseCache(text, wordLength: wordLength)
        }
        return [:]
    }

    func download(wordLength: Int) async throws -> [String: FrequencyRecord] {
        let (data, response) = try await URLSession.shared.data(from: subtlexURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let downloaded = parseSUBTLEX(text, wordLength: wordLength)
        guard !downloaded.isEmpty else { throw URLError(.cannotParseResponse) }

        let existing = cached(wordLength: wordLength)
        var merged = existing
        for (word, incoming) in downloaded {
            let prior = existing[word]
            merged[word] = FrequencyRecord(
                primaryZipf: prior?.primaryZipf,
                subtlexZipf: incoming.subtlexZipf,
                subtlexFrequencyPerMillion: incoming.subtlexFrequencyPerMillion
            )
        }

        try writeCache(merged, wordLength: wordLength)
        return merged
    }

    /// Imports a compact frequency CSV for one puzzle length. Expected columns:
    /// `word,zipf`.
    func importPrimaryCSV(_ text: String, wordLength: Int) throws -> [String: FrequencyRecord] {
        var merged = cached(wordLength: wordLength)
        var imported = 0

        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 2 else { continue }
            let word = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard word.count == wordLength, word.allSatisfy({ $0.isLetter }) else { continue }
            guard let zipf = Double(fields[1].trimmingCharacters(in: .whitespacesAndNewlines)), zipf > 0 else { continue }

            let prior = merged[word]
            merged[word] = FrequencyRecord(
                primaryZipf: zipf,
                subtlexZipf: prior?.subtlexZipf,
                subtlexFrequencyPerMillion: prior?.subtlexFrequencyPerMillion
            )
            imported += 1
        }

        guard imported > 0 else { throw URLError(.cannotParseResponse) }
        try writeCache(merged, wordLength: wordLength)
        return merged
    }

    private func parseSUBTLEX(_ text: String, wordLength: Int) -> [String: FrequencyRecord] {
        var result: [String: FrequencyRecord] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 2 else { continue }
            let word = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard word.count == wordLength, word.allSatisfy({ $0.isLetter }) else { continue }
            guard let freq = Double(fields[1].trimmingCharacters(in: .whitespacesAndNewlines)), freq > 0 else { continue }
            let zipf = log10(freq * 1000)
            result[word] = FrequencyRecord(
                primaryZipf: nil,
                subtlexZipf: zipf,
                subtlexFrequencyPerMillion: freq
            )
        }
        return result
    }

    private func parseCache(_ text: String, wordLength: Int) -> [String: FrequencyRecord] {
        var result: [String: FrequencyRecord] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 4 else { continue }
            let word = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard word.count == wordLength, word.allSatisfy({ $0.isLetter }) else { continue }
            if word == "word" { continue }

            func optionalDouble(_ value: Substring) -> Double? {
                let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : Double(t)
            }

            result[word] = FrequencyRecord(
                primaryZipf: optionalDouble(fields[1]),
                subtlexZipf: optionalDouble(fields[2]),
                subtlexFrequencyPerMillion: optionalDouble(fields[3])
            )
        }
        return result
    }

    private func writeCache(_ records: [String: FrequencyRecord], wordLength: Int) throws {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        var lines = ["word,primary_zipf,subtlex_zipf,subtlex_freq_per_million"]
        for word in records.keys.sorted() {
            guard let rec = records[word] else { continue }
            let primary = rec.primaryZipf.map { String($0) } ?? ""
            let subtlex = rec.subtlexZipf.map { String($0) } ?? ""
            let freq = rec.subtlexFrequencyPerMillion.map { String($0) } ?? ""
            lines.append("\(word),\(primary),\(subtlex),\(freq)")
        }
        try lines.joined(separator: "\n").write(to: cacheURL(wordLength: wordLength), atomically: true, encoding: .utf8)
    }

    private var cacheDirectory: URL {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = support.appendingPathComponent("CoSolve", isDirectory: true)
        let legacy = support.appendingPathComponent("SixLetterSolver", isDirectory: true)

        // Preserve dictionaries/frequency data downloaded by earlier Co-Solve builds.
        if !fileManager.fileExists(atPath: current.path),
           fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.copyItem(at: legacy, to: current)
        }

        return current
    }

    private func cacheURL(wordLength: Int) -> URL {
        cacheDirectory.appendingPathComponent("frequency_\(wordLength)_v3.csv")
    }

    private var legacyCacheURL: URL {
        cacheDirectory.appendingPathComponent("frequency_v2.csv")
    }
}
