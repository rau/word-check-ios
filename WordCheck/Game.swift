import Foundation

struct Tile: Codable, Equatable {
    let letter: String
    let blank: Bool
    var value: Int { blank ? 0 : BoardRules.values[letter, default: 0] }
}
struct Placement: Codable, Equatable { let index: Int; let tile: Tile }
struct ScoredWord: Equatable { let word: String; let score: Int }
struct PlayResult {
    let placements: [Placement]
    let words: [ScoredWord]
    let bonus: Int
    var score: Int { words.reduce(bonus) { $0 + $1.score } }
}
struct GameTurn: Codable {
    let player: Int
    let title: String
    let placements: [Placement]
    let changes: [Int]
    let kind: String
    var lexicon: Int? = nil
    var challengedTurn: Int? = nil
}
struct TrackedGame: Codable {
    let names: [String]
    var lexicon: Int
    var turns: [GameTurn] = []
    var finished: Bool { turns.last?.kind == "finish" }
    var currentPlayer: Int { turns.filter { $0.kind != "finish" && $0.kind != "challengeWon" }.count % names.count }
    var scores: [Int] { names.indices.map { i in turns.reduce(0) { $0 + $1.changes[i] } } }
    var board: [Tile?] {
        var result = [Tile?](repeating: nil, count: 225)
        for turn in turns {
            for p in turn.placements { result[p.index] = p.tile }
            if turn.kind == "challengeWon", let index = turn.challengedTurn, turns.indices.contains(index) {
                for p in turns[index].placements { result[p.index] = nil }
            }
        }
        return result
    }
    var scorelessTurns: Int { turns.reversed().prefix { $0.kind != "finish" && $0.changes.allSatisfy { $0 == 0 } }.count }
    mutating func play(_ result: PlayResult) {
        guard !finished else { return }
        var changes = names.map { _ in 0 }; changes[currentPlayer] = result.score
        turns.append(GameTurn(player: currentPlayer, title: result.words.map(\.word).joined(separator: " · "), placements: result.placements, changes: changes, kind: "play", lexicon: lexicon))
    }
    mutating func skip(exchange: Bool) {
        guard !finished else { return }
        turns.append(GameTurn(player: currentPlayer, title: exchange ? "Exchange" : "Pass", placements: [], changes: names.map { _ in 0 }, kind: exchange ? "exchange" : "pass"))
    }
    var canChallenge: Bool { !finished && turns.last?.kind == "play" }
    /// The challenger keeps their turn on success; a failed challenge consumes it.
    /// The dictionary recorded with the play is used even after a mid-game switch.
    mutating func challenge(valid: (String, Int) -> Bool) throws -> Bool {
        guard canChallenge, let previous = turns.last else { throw RuleError("There is no play to challenge.") }
        let words = previous.title.components(separatedBy: " · ")
        let successful = words.contains { !valid($0, previous.lexicon ?? lexicon) }
        let changes = successful ? previous.changes.map { -$0 } : names.map { _ in 0 }
        turns.append(GameTurn(player: currentPlayer, title: successful ? "Challenge successful" : "Challenge unsuccessful", placements: [], changes: changes, kind: successful ? "challengeWon" : "challengeLost", lexicon: previous.lexicon ?? lexicon, challengedTurn: turns.count - 1))
        return successful
    }
    mutating func finish(racks: [String], wentOut: Int?) throws {
        guard !finished, racks.count == names.count else { throw RuleError("This game has already ended.") }
        var penalties = [Int]()
        for rack in racks {
            let raw = rack.trimmingCharacters(in: .whitespacesAndNewlines)
            guard raw.utf8.count <= 7, raw.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || $0 == 63 }) else { throw RuleError("Enter up to 7 remaining letters per player. Use ? for a blank.") }
            let letters = raw.uppercased()
            penalties.append(letters.reduce(0) { $0 + BoardRules.values[String($1), default: 0] })
        }
        if let p = wentOut {
            guard names.indices.contains(p), racks[p].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RuleError("The player who went out must have no tiles remaining.") }
        }
        var changes = penalties.map { -$0 }
        if let p = wentOut { changes[p] += penalties.reduce(0, +) }
        turns.append(GameTurn(player: currentPlayer, title: "Final rack adjustments", placements: [], changes: changes, kind: "finish"))
    }
}
struct TypedPlay {
    let word: String
    let blanks: Set<Int>
    static func parse(_ input: String) throws -> TypedPlay {
        let text=input.trimmingCharacters(in:.whitespacesAndNewlines)
        var letters="", blanks=Set<Int>()
        for byte in text.utf8 {
            guard byte == 63 || (65...90).contains(byte) || (97...122).contains(byte) else { throw RuleError("Use letters A–Z or ? for a blank.") }
            if byte == 63 || (97...122).contains(byte) { blanks.insert(letters.count) }
            letters.append(Character(UnicodeScalar(byte >= 97 ? byte-32 : byte)))
        }
        return TypedPlay(word:letters,blanks:blanks)
    }
}
struct RuleError: LocalizedError { let message: String; init(_ message: String) { self.message = message }; var errorDescription: String? { message } }
enum Premium: String { case none = "", doubleLetter = "2L", tripleLetter = "3L", doubleWord = "2W", tripleWord = "3W" }
enum BoardRules {
    static let values: [String: Int] = Dictionary(uniqueKeysWithValues: [("AEILNORSTU",1),("DG",2),("BCMP",3),("FHVWY",4),("K",5),("JX",8),("QZ",10)].flatMap { letters, value in letters.map { (String($0), value) } })
    static let supply: [String: Int] = ["A":9,"B":2,"C":2,"D":4,"E":12,"F":2,"G":3,"H":2,"I":9,"J":1,"K":1,"L":4,"M":2,"N":6,"O":8,"P":2,"Q":1,"R":6,"S":4,"T":6,"U":4,"V":2,"W":2,"X":1,"Y":2,"Z":1,"?":2]
    static func coordinate(_ index: Int) -> String { "\(String(UnicodeScalar(65 + index % 15)!))\(index / 15 + 1)" }
    static func premium(_ index: Int) -> Premium {
        let r = index / 15, c = index % 15
        if [0,7,14].contains(r), [0,7,14].contains(c), index != 112 { return .tripleWord }
        if r == c && [1,2,3,4,7,10,11,12,13].contains(r) || r+c == 14 && [1,2,3,4,10,11,12,13].contains(r) { return .doubleWord }
        if [1,13].contains(r) && [5,9].contains(c) || [5,9].contains(r) && [1,5,9,13].contains(c) { return .tripleLetter }
        let doubles: Set<Int> = [3,11,36,38,45,52,59,92,96,98,102,108,116,122,126,128,132,165,172,179,186,188,213,221]
        return doubles.contains(index) ? .doubleLetter : .none
    }
    static func evaluate(board: [Tile?], word: String, start: Int, vertical: Bool, blanks: Set<Int>, valid: (String) -> Bool) throws -> PlayResult {
        let raw = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }), raw.count <= 15 else { throw RuleError("Enter 1–15 letters, including any tiles already on the board.") }
        guard board.count == 225, (0..<225).contains(start) else { throw RuleError("Choose a starting square.") }
        let letters = Array(raw.uppercased()).map(String.init)
        guard (vertical ? start / 15 : start % 15) + letters.count <= 15 else { throw RuleError("That word runs past the edge of the board.") }
        var candidate = board, placements = [Placement]()
        for (offset, letter) in letters.enumerated() {
            let index = start + offset * (vertical ? 15 : 1)
            if let tile = board[index] {
                guard tile.letter == letter else { throw RuleError("\(coordinate(index)) already contains \(tile.letter). Include existing letters in your word.") }
            } else {
                let tile = Tile(letter: letter, blank: blanks.contains(offset))
                candidate[index] = tile; placements.append(Placement(index: index, tile: tile))
            }
        }
        guard !placements.isEmpty else { throw RuleError("Place at least one new tile.") }
        guard placements.count <= 7 else { throw RuleError("You can place at most 7 new tiles in one turn.") }
        let newIndices = Set(placements.map(\.index))
        if board.allSatisfy({ $0 == nil }) {
            guard newIndices.contains(112) else { throw RuleError("The first word must cover the center star (H8).") }
        } else {
            let connected = placements.contains { p in
                let r = p.index / 15, c = p.index % 15
                if r > 0 && board[p.index-15] != nil { return true }
                if r < 14 && board[p.index+15] != nil { return true }
                if c > 0 && board[p.index-1] != nil { return true }
                if c < 14 && board[p.index+1] != nil { return true }
                return false
            }
            guard connected else { throw RuleError("Connect your play to a tile already on the board.") }
        }
        var counts = [String: Int]()
        for tile in candidate.compactMap({ $0 }) { counts[tile.blank ? "?" : tile.letter, default: 0] += 1 }
        for (letter,count) in counts where count > supply[letter, default: 0] { throw RuleError("Too many \(letter == "?" ? "blank" : letter) tiles for a standard English set. Mark a letter as blank if needed.") }
        func run(_ index: Int, _ down: Bool) -> [Int] {
            let step = down ? 15 : 1
            var first = index
            while (down ? first >= 15 : first % 15 > 0), candidate[first-step] != nil { first -= step }
            var result = [Int](), cursor = first
            while cursor < 225, candidate[cursor] != nil {
                result.append(cursor)
                if !down && cursor % 15 == 14 { break }
                cursor += step
            }
            return result
        }
        var runs = [[Int]]()
        for p in placements { for down in [false,true] {
            let indices = run(p.index, down)
            if indices.count > 1 && !runs.contains(indices) { runs.append(indices) }
        } }
        guard !runs.isEmpty else { throw RuleError("A play must form a word of at least 2 letters.") }
        var words = [ScoredWord](), invalid = [String]()
        for indices in runs {
            let text = indices.map { candidate[$0]!.letter }.joined()
            if !valid(text) { invalid.append(text) }
            var sum = 0, multiplier = 1
            for i in indices {
                var value = candidate[i]!.value
                if newIndices.contains(i) {
                    switch premium(i) { case .doubleLetter: value *= 2; case .tripleLetter: value *= 3; case .doubleWord: multiplier *= 2; case .tripleWord: multiplier *= 3; case .none: break }
                }
                sum += value
            }
            words.append(ScoredWord(word: text, score: sum * multiplier))
        }
        guard invalid.isEmpty else { throw RuleError("Not valid: \(invalid.joined(separator: ", ")). No tiles have been played.") }
        return PlayResult(placements: placements, words: words, bonus: placements.count == 7 ? 50 : 0)
    }
}
final class GameStore {
    private let url: URL
    init(url: URL? = nil) {
        if let url { self.url = url; return }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = folder.appendingPathComponent("game.json")
    }
    func load() throws -> TrackedGame? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let game = try JSONDecoder().decode(TrackedGame.self, from: Data(contentsOf: url))
        guard (2...4).contains(game.names.count), (0...1).contains(game.lexicon), game.turns.allSatisfy({ t in game.names.indices.contains(t.player) && t.changes.count == game.names.count && t.placements.allSatisfy({ (0..<225).contains($0.index) }) }) else { throw RuleError("The saved game could not be read.") }
        var totals = Array(repeating: 0, count: game.names.count)
        let kinds: Set<String> = ["play", "pass", "exchange", "finish", "challengeWon", "challengeLost"]
        for (index, turn) in game.turns.enumerated() {
            guard kinds.contains(turn.kind), turn.lexicon.map({ (0...1).contains($0) }) ?? true,
                  turn.changes.allSatisfy({ (-100_000...100_000).contains($0) }),
                  turn.placements.allSatisfy({ $0.tile.letter.utf8.count == 1 && $0.tile.letter.utf8.allSatisfy { (65...90).contains($0) } }) else {
                throw RuleError("The saved game could not be read.")
            }
            if turn.kind == "challengeWon" || turn.kind == "challengeLost" {
                guard let previous = turn.challengedTurn, previous == index - 1, previous >= 0,
                      game.turns[previous].kind == "play" else { throw RuleError("The saved game could not be read.") }
            }
            for player in totals.indices {
                let sum = totals[player].addingReportingOverflow(turn.changes[player])
                guard !sum.overflow else { throw RuleError("The saved game could not be read.") }
                totals[player] = sum.partialValue
            }
        }
        return game
    }
    func save(_ game: TrackedGame) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(game).write(to: url, options: .atomic)
    }
}

/// Only the player's new tiles are editable; board letters are derived on every edit.
struct BoardDraft {
    var input = ""
    struct Display {
        let text: String
        let sources: [Int?]
    }
    func display(board: [Tile?], start: Int, vertical: Bool) -> Display {
        guard !input.isEmpty else { return Display(text:"",sources:[]) }
        let chars=Array(input)
        var text="", sources=[Int?](), offset=0, position=0
        func appendExisting() {
            while (vertical ? start/15 : start%15)+position < 15 {
                let index=start+position*(vertical ? 15 : 1)
                guard board.indices.contains(index), let tile=board[index] else { break }
                text += tile.letter; sources.append(nil); position += 1
            }
        }
        appendExisting()
        while offset < chars.count {
            text.append(chars[offset]); sources.append(offset); offset += 1; position += 1
            appendExisting()
        }
        return Display(text:text,sources:sources)
    }
    mutating func edit(range: NSRange, replacement: String, display: Display) -> Int {
        var chars=Array(input)
        let lower=min(range.location,display.sources.count)
        let upper=min(range.location+range.length,display.sources.count)
        var removed=Set(display.sources[lower..<upper].compactMap { $0 })
        var insertion=display.sources.prefix(lower).compactMap { $0 }.last.map { $0+1 } ?? 0
        // Backspace on an automatically included letter goes back to the last new tile.
        if replacement.isEmpty, range.length > 0, removed.isEmpty,
           let previous=display.sources.prefix(lower).compactMap({$0}).last { removed.insert(previous) }
        if let first=removed.min() { insertion=first }
        for index in removed.sorted(by:>) { chars.remove(at:index) }
        insertion=min(insertion,chars.count)
        // A board line is at most 15 squares. Reject an oversized paste atomically,
        // before preview construction can repeatedly scan a huge string.
        guard replacement.utf8.count <= 15,
              replacement.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || $0 == 63 }),
              chars.count + replacement.utf8.count <= 15 else { return min(lower, input.count) }
        chars.insert(contentsOf:Array(replacement.uppercased()),at:insertion)
        input=String(chars)
        return insertion+replacement.count
    }
}
