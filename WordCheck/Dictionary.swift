import Foundation

enum Lexicon: Int, CaseIterable {
    case naspa, collins
    var resource: String { self == .naspa ? "NWL2023" : "CSW24" }
    var title: String { self == .naspa ? "NASPA" : "Collins" }
    var detail: String { self == .naspa ? "NWL 2023 · US & Canada" : "CSW 2024 · International" }
}

final class WordDictionary {
    private let words: [Lexicon: Set<String>]
    init(bundle: Bundle = .main) throws {
        words = try Dictionary(uniqueKeysWithValues: Lexicon.allCases.map { lexicon in
            guard let url = bundle.url(forResource: lexicon.resource, withExtension: "txt") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let contents = try String(contentsOf: url, encoding: .utf8)
            let list = Set(contents.split(whereSeparator: \.isWhitespace).map(String.init))
            guard list.count == (lexicon == .naspa ? 196601 : 280887) else { throw CocoaError(.fileReadCorruptFile) }
            return (lexicon, list)
        })
    }
    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(with: Locale(identifier: "en_US_POSIX"))
    }
    static func inputError(_ text: String) -> String? {
        let word = normalize(text)
        guard !word.isEmpty else { return "Enter a word to check." }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }) else { return "Use letters A–Z only. Check one word at a time." }
        guard (2...15).contains(word.count) else { return "Enter a word with 2–15 letters." }
        return nil
    }
    func contains(_ word: String, in lexicon: Lexicon) -> Bool {
        words[lexicon]?.contains(Self.normalize(word)) == true
    }
}
