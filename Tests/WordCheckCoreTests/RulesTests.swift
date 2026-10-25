import XCTest
@testable import WordCheckCore

class RulesTests: XCTestCase {
    let empty = [Tile?](repeating: nil, count: 225)
    func play(_ board: [Tile?], _ word: String, _ start: Int = 112, down: Bool = false, blanks: Set<Int> = []) throws -> PlayResult {
        try BoardRules.evaluate(board: board, word: word, start: start, vertical: down, blanks: blanks, valid: { _ in true })
    }
    func testPremiumLayoutAndSymmetry() {
        for (premium, count) in [(Premium.tripleWord,8),(.doubleWord,17),(.tripleLetter,12),(.doubleLetter,24),(.none,164)] {
            XCTAssertEqual((0..<225).filter { BoardRules.premium($0) == premium }.count, count)
        }
        for i in 0..<225 {
            XCTAssertEqual(BoardRules.premium(i), BoardRules.premium(224-i))
            XCTAssertEqual(BoardRules.premium(i), BoardRules.premium(i%15*15+i/15))
        }
        XCTAssertEqual(BoardRules.coordinate(0), "A1")
        XCTAssertEqual(BoardRules.coordinate(112), "H8")
        XCTAssertEqual(BoardRules.coordinate(224), "O15")
    }
    func testTileValuesAndSupply() {
        XCTAssertEqual(BoardRules.supply.values.reduce(0,+),100)
        XCTAssertEqual(BoardRules.values.count,26)
        for (letters,value) in [("AEILNORSTU",1),("DG",2),("BCMP",3),("FHVWY",4),("K",5),("JX",8),("QZ",10)] {
            for letter in letters {
                XCTAssertEqual(Tile(letter:String(letter),blank:false).value,value)
                XCTAssertEqual(Tile(letter:String(letter),blank:true).value,0)
            }
        }
    }
    func testOpeningAndBingo() throws {
        XCTAssertEqual(try play(empty," cat\n").score,10)
        let bingo=try play(empty,"READING",109)
        XCTAssertEqual(bingo.bonus,50)
        XCTAssertEqual(bingo.words,[ScoredWord(word:"READING",score:18)])
        XCTAssertEqual(bingo.score,68)
        XCTAssertEqual(try play(empty,"CAT",blanks:[0]).score,4)
    }
    func testInvalidInputAndBoardBounds() {
        for word in ["", " ", "A", "é", "ß", "A B", "A?", "😀", String(repeating:"A",count:16)] {
            XCTAssertThrowsError(try play(empty,word),word)
        }
        for start in [-1,225,Int.max] { XCTAssertThrowsError(try play(empty,"AT",start)) }
        XCTAssertThrowsError(try play([],"AT"))
        XCTAssertThrowsError(try play(empty,"AT",119))
        XCTAssertThrowsError(try play(empty,"AT",224,down:true))
        XCTAssertThrowsError(try play(empty,"CAT",0))
        XCTAssertThrowsError(try play(empty,"RELATION",109))
    }
    func testExistingTilesCannotBeOverwrittenOrReplayed() throws {
        var game=TrackedGame(names:["A","B"],lexicon:0)
        game.play(try play(empty,"CAT"))
        XCTAssertThrowsError(try play(game.board,"DOG"))
        XCTAssertThrowsError(try play(game.board,"CAT"))
        XCTAssertThrowsError(try play(game.board,"DOG",0))
        let extensionPlay=try play(game.board,"S",115)
        XCTAssertEqual(extensionPlay.words,[ScoredWord(word:"CATS",score:6)])
        XCTAssertEqual(extensionPlay.placements.count,1)
    }
    func testAllPremiumsApplyOnlyToNewTiles() throws {
        // Isolate a two-letter run at every square, in both orientations.
        for index in 0..<225 {
            for down in [false,true] {
                let coordinate=down ? index/15 : index%15
                let neighbor=index+(coordinate>0 ? -1:1)*(down ? 15:1)
                var board=empty; board[neighbor]=Tile(letter:"A",blank:false)
                let expected: Int
                switch BoardRules.premium(index) {
                case .none: expected=4
                case .doubleLetter: expected=7
                case .tripleLetter: expected=10
                case .doubleWord: expected=8
                case .tripleWord: expected=12
                }
                XCTAssertEqual(try play(board,"C",index,down:down).score,expected,"square \(index)")
                let blankExpected = BoardRules.premium(index) == .doubleWord ? 2 : BoardRules.premium(index) == .tripleWord ? 3 : 1
                XCTAssertEqual(try play(board,"C",index,down:down,blanks:[0]).score,blankExpected)
            }
        }
    }
    func testCrosswordScoringAndDictionaryValidation() throws {
        var board=empty;board[111]=Tile(letter:"A",blank:false);board[97]=Tile(letter:"I",blank:false)
        let result=try play(board,"T")
        XCTAssertEqual(Set(result.words.map(\.word)),Set(["AT","IT"]))
        XCTAssertEqual(result.score,8)
        var checked=[String]()
        XCTAssertThrowsError(try BoardRules.evaluate(board:board,word:"T",start:112,vertical:false,blanks:[]) {
            checked.append($0);return $0 != "IT"
        })
        XCTAssertEqual(Set(checked),Set(["AT","IT"]))
        XCTAssertNil(board[112])
    }
    func testBoardEdgesDoNotConnectAcrossRows() {
        var board=empty;board[14]=Tile(letter:"A",blank:false)
        XCTAssertThrowsError(try play(board,"AT",15))
        board=empty;board[210]=Tile(letter:"A",blank:false)
        XCTAssertThrowsError(try play(board,"AT",194,down:true))
    }
    func testSupplyAndExistingBlanks() throws {
        XCTAssertThrowsError(try play(empty,"QQ"))
        XCTAssertEqual(try play(empty,"QQ",blanks:[1]).score,20)
        XCTAssertThrowsError(try play(empty,"AAA",blanks:[0,1,2]))
        var board=empty;board[112]=Tile(letter:"Q",blank:true)
        XCTAssertEqual(try play(board,"QI").score,1)
    }
    func testMultipleWordMultipliersCompound() throws {
        var board=empty
        for i in 1...6 { board[i]=Tile(letter:"A",blank:false) }
        let result=try play(board,"A",0)
        XCTAssertEqual(result.score,21)
        // Two new triple-word squares with six existing connecting tiles.
        let both=try play(board,"AAAAAAAA",0)
        XCTAssertEqual(both.placements.count,2)
        XCTAssertEqual(both.score,72)
        XCTAssertEqual(both.bonus,0)
    }
}
