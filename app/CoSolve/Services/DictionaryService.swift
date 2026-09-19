import Foundation

actor DictionaryService {
    static let shared = DictionaryService()

    enum Source: String, CaseIterable, Identifiable {
        case common = "Common words"
        case comprehensive = "Comprehensive dictionary"
        var id: String { rawValue }
    }

    private let commonURL = URL(string: "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-usa-no-swears.txt")!
    private let comprehensiveURL = URL(string: "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt")!

    func builtInWords(wordLength: Int) -> [String] {
        guard let url = Bundle.main.url(forResource: "BuiltInWords", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return normalize(text.components(separatedBy: .whitespacesAndNewlines), wordLength: wordLength)
    }

    func cachedSources(wordLength: Int) -> Set<Source> {
        var sources = Set<Source>()

        if FileManager.default.fileExists(atPath: cacheURL(name: "common_words_\(wordLength).txt").path) {
            sources.insert(.common)
        }
        if FileManager.default.fileExists(atPath: cacheURL(name: "comprehensive_words_\(wordLength).txt").path) {
            sources.insert(.comprehensive)
        }

        // v1.22 compatibility: recognise previously downloaded six-letter caches.
        if wordLength == 6 {
            if FileManager.default.fileExists(atPath: cacheURL(name: "common_words.txt").path) {
                sources.insert(.common)
            }
            if FileManager.default.fileExists(atPath: cacheURL(name: "comprehensive_words.txt").path) {
                sources.insert(.comprehensive)
            }
        }

        return sources
    }

    func cachedWords(wordLength: Int) -> [String] {
        var words = Set(builtInWords(wordLength: wordLength))

        let currentURLs = [
            cacheURL(name: "common_words_\(wordLength).txt"),
            cacheURL(name: "comprehensive_words_\(wordLength).txt")
        ]

        for url in currentURLs {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                words.formUnion(normalize(text.components(separatedBy: .whitespacesAndNewlines), wordLength: wordLength))
            }
        }

        // v1.22 compatibility: preserve existing six-letter downloads.
        if wordLength == 6 {
            for legacyName in ["common_words.txt", "comprehensive_words.txt"] {
                let url = cacheURL(name: legacyName)
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    words.formUnion(normalize(text.components(separatedBy: .whitespacesAndNewlines), wordLength: wordLength))
                }
            }
        }

        return words.sorted()
    }

    func download(_ source: Source, wordLength: Int) async throws -> [String] {
        let url = source == .common ? commonURL : comprehensiveURL
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let words = normalize(text.components(separatedBy: .whitespacesAndNewlines), wordLength: wordLength)
        guard !words.isEmpty else { throw URLError(.cannotParseResponse) }

        let kind = source == .common ? "common_words" : "comprehensive_words"
        let target = cacheURL(name: "\(kind)_\(wordLength).txt")
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try words.joined(separator: "\n").write(to: target, atomically: true, encoding: .utf8)
        return cachedWords(wordLength: wordLength)
    }

    private func normalize(_ words: [String], wordLength: Int) -> [String] {
        var seen = Set<String>()
        return words.compactMap { raw in
            let word = raw.lowercased().filter { $0.isLetter }
            guard word.count == wordLength, seen.insert(word).inserted else { return nil }
            return word
        }.sorted()
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

    private func cacheURL(name: String) -> URL {
        cacheDirectory.appendingPathComponent(name)
    }
}
