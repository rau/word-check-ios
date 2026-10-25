import Foundation

@main struct Checks {
    static func main() throws {
        let bundle = Bundle(path: CommandLine.arguments[1])!
        let dictionary = try WordDictionary(bundle: bundle)
        for lexicon in Lexicon.allCases {
            for word in ["QI", "ZA", "HELLO", "SCRABBLE", "AA"] {
                precondition(dictionary.contains(word, in: lexicon), "Missing \(word) from \(lexicon)")
            }
            for word in ["ZZZZ", "XYZZZZ", "A", "NOTAWORDXYZ"] {
                precondition(!dictionary.contains(word, in: lexicon), "Unexpected \(word)")
            }
            precondition(dictionary.contains(" qi\n", in: lexicon))
        }
        precondition(!dictionary.contains("CH", in: .naspa))
        precondition(dictionary.contains("CH", in: .collins))
        precondition(WordDictionary.inputError("hello") == nil)
        precondition(WordDictionary.inputError(" qi\n") == nil)
        for invalid in ["", " ", "a", "hello world", "can't", "café", "ß", "１２", "123", "😀", String(repeating: "A", count: 16)] {
            precondition(WordDictionary.inputError(invalid) != nil, "Accepted invalid input: \(invalid)")
        }
        do { _ = try WordDictionary(bundle: Bundle(path: "/tmp")!); fatalError("Accepted missing dictionary") }
        catch { }
        print("PASS: full dictionaries loaded; known valid/invalid words, Collins/NASPA distinction, whitespace/case, input errors, missing resources")
    }
}
