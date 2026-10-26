import XCTest
@testable import WordCheckCore

final class StressTests: XCTestCase {
    struct Random {
        var state:UInt64 = 0x7a091
        mutating func next(_ upper:Int)->Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(upper))
        }
    }
    func testOversizedPasteIsRejectedWithoutChangingDraft() {
        var draft=BoardDraft(input:"CAT")
        let board=[Tile?](repeating:nil,count:225)
        let display=draft.display(board:board,start:112,vertical:false)
        _=draft.edit(range:NSRange(location:3,length:0),replacement:String(repeating:"A",count:100_000),display:display)
        XCTAssertEqual(draft.input,"CAT")
    }
    func testUnicodeRackCannotBecomeDifferentLetters() {
        for invalid in ["ß","ı","ﬀ"] {
            var game=TrackedGame(names:["A","B"],lexicon:0)
            XCTAssertThrowsError(try game.finish(racks:[invalid,""],wentOut:nil),invalid)
            XCTAssertTrue(game.turns.isEmpty)
        }
    }
    func testCorruptScoreCannotOverflowOnLoad() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:url)}
        let store=GameStore(url:url)
        let turns=[GameTurn(player:0,title:"CAT",placements:[],changes:[Int.max,0],kind:"play"),GameTurn(player:1,title:"AT",placements:[],changes:[1,0],kind:"play")]
        try store.save(TrackedGame(names:["A","B"],lexicon:0,turns:turns))
        XCTAssertThrowsError(try store.load())
    }
    func testRejectedReplacementIsAtomicAndInvalidSaveFieldsAreRejected() throws {
        var draft=BoardDraft(input:"CAT")
        let board=[Tile?](repeating:nil,count:225)
        let display=draft.display(board:board,start:112,vertical:false)
        for replacement in ["ß",String(repeating:"A",count:16)] {
            _=draft.edit(range:NSRange(location:0,length:3),replacement:replacement,display:display)
            XCTAssertEqual(draft.input,"CAT")
        }
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:url)}
        let store=GameStore(url:url)
        let invalid=[
            GameTurn(player:0,title:"x",placements:[],changes:[Int.min,0],kind:"play"),
            GameTurn(player:0,title:"x",placements:[],changes:[0,0],kind:"unknown"),
            GameTurn(player:0,title:"x",placements:[],changes:[0,0],kind:"play",lexicon:9),
            GameTurn(player:0,title:"x",placements:[Placement(index:112,tile:Tile(letter:"AB",blank:true))],changes:[0,0],kind:"play"),
            GameTurn(player:0,title:"x",placements:[],changes:[0,0],kind:"challengeWon",challengedTurn:99)
        ]
        for turn in invalid {
            try store.save(TrackedGame(names:["A","B"],lexicon:0,turns:[turn]))
            XCTAssertThrowsError(try store.load())
        }
    }
    func testTenThousandRandomDraftEditsPreserveBoardAndSourceMapping() {
        var random=Random()
        let alphabet=Array("AEIRST?")
        for _ in 0..<100 {
            var board=[Tile?](repeating:nil,count:225)
            for i in 0..<225 where random.next(4)==0 {board[i]=Tile(letter:"A",blank:random.next(8)==0)}
            let saved=board,start=random.next(225),down=random.next(2)==0
            var draft=BoardDraft()
            for _ in 0..<100 {
                let display=draft.display(board:board,start:start,vertical:down)
                let lower=random.next(display.sources.count+1)
                let length=random.next(display.sources.count-lower+1)
                let replacement=random.next(3)==0 ? "":String(alphabet[random.next(alphabet.count)])
                _=draft.edit(range:NSRange(location:lower,length:length),replacement:replacement,display:display)
                let updated=draft.display(board:board,start:start,vertical:down)
                XCTAssertEqual(updated.text.count,updated.sources.count)
                XCTAssertEqual(updated.sources.compactMap{$0},Array(0..<draft.input.count))
                XCTAssertEqual(String(zip(updated.text,updated.sources).compactMap { $0.1 == nil ? nil:$0.0 }),draft.input)
                XCTAssertEqual(board,saved)
            }
        }
    }
    func testRandomPlaysChallengesUndoAndPersistence() throws {
        var random=Random()
        let empty=[Tile?](repeating:nil,count:225)
        for _ in 0..<40 {
            var game=TrackedGame(names:["A","B","C","D"],lexicon:random.next(2))
            for _ in 0..<80 {
                let before=game,action=random.next(5)
                if action==0, !game.turns.isEmpty {game.turns.removeLast()}
                else if action==1,game.canChallenge {
                    let won=random.next(2)==0,challenger=game.currentPlayer
                    XCTAssertEqual(try game.challenge {_,_ in !won},won)
                    XCTAssertEqual(game.currentPlayer,won ? challenger:(challenger+1)%4)
                } else if action==2 {game.skip(exchange:random.next(2)==0)}
                else {
                    let start=game.turns.isEmpty ? 112:random.next(225)
                    if let move=try? BoardRules.evaluate(board:game.board,word:["AT","IT","QI","ZA","CAT"][random.next(5)],start:start,vertical:random.next(2)==0,blanks:[],valid:{_ in true}) {
                        let player=game.currentPlayer,scores=game.scores
                        game.play(move)
                        XCTAssertEqual(game.scores[player],scores[player]+move.score)
                        for i in 0..<225 where !move.placements.contains(where:{$0.index==i}) {XCTAssertEqual(game.board[i],before.board[i])}
                    }
                }
                let loaded=try JSONDecoder().decode(TrackedGame.self,from:JSONEncoder().encode(game))
                XCTAssertEqual(loaded.board,game.board);XCTAssertEqual(loaded.scores,game.scores)
                XCTAssertEqual(loaded.currentPlayer,game.currentPlayer)
                if game.turns.isEmpty {XCTAssertEqual(game.board,empty)}
            }
        }
    }
}
