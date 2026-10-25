import XCTest
@testable import WordCheckCore

final class GameTests: XCTestCase {
    let empty = [Tile?](repeating:nil,count:225)
    func play(_ board:[Tile?], _ word:String, _ start:Int = 112, down:Bool = false) throws -> PlayResult {
        try BoardRules.evaluate(board:board,word:word,start:start,vertical:down,blanks:[],valid:{_ in true})
    }
    func testRotationPassExchangeAndUndoForEveryPlayerCount() throws {
        for count in 2...4 {
            var game=TrackedGame(names:(0..<count).map { "Player \($0)" },lexicon:0)
            for turn in 0..<12 {
                XCTAssertEqual(game.currentPlayer,turn%count)
                game.skip(exchange:turn%2==0)
                XCTAssertEqual(game.turns.last?.kind,turn%2==0 ? "exchange":"pass")
            }
            XCTAssertEqual(game.scorelessTurns,12)
            XCTAssertEqual(game.scores,Array(repeating:0,count:count))
            game.turns.removeLast();XCTAssertEqual(game.currentPlayer,11%count)
        }
    }
    func testChallengeSuccessUndoAndRecordedDictionary() throws {
        var game=TrackedGame(names:["A","B","C"],lexicon:0)
        game.play(try play(empty,"CAT"))
        let priorBoard=game.board
        game.play(try play(game.board,"AZ",113,down:true))
        game.lexicon=1
        XCTAssertTrue(try game.challenge { word,lexicon in
            XCTAssertEqual(lexicon,0);XCTAssertEqual(word,"AZ");return false
        })
        XCTAssertEqual(game.board,priorBoard)
        XCTAssertEqual(game.scores,[10,0,0])
        XCTAssertEqual(game.currentPlayer,2)
        XCTAssertEqual(game.turns[1].title,"AZ")
        XCTAssertFalse(game.canChallenge)
        XCTAssertThrowsError(try game.challenge { _,_ in false })
        game.turns.removeLast()
        XCTAssertEqual(game.board[128]?.letter,"Z")
        XCTAssertEqual(game.scores,[10,21,0])
        XCTAssertTrue(game.canChallenge)
    }
    func testFailedChallengeConsumesExactlyOneTurn() throws {
        for count in 2...4 {
            var game=TrackedGame(names:(0..<count).map(String.init),lexicon:1)
            game.play(try play(empty,"CAT"));let board=game.board
            XCTAssertFalse(try game.challenge { _,edition in XCTAssertEqual(edition,1);return true })
            XCTAssertEqual(game.currentPlayer,2%count)
            XCTAssertEqual(game.board,board)
            XCTAssertEqual(game.scores[0],10)
            XCTAssertFalse(game.canChallenge)
        }
    }
    func testChallengeChecksCrosswordsAndExpiresAfterPass() throws {
        var game=TrackedGame(names:["A","B"],lexicon:0)
        game.play(PlayResult(placements:[],words:[ScoredWord(word:"AT",score:2),ScoredWord(word:"ZZ",score:20)],bonus:0))
        XCTAssertTrue(try game.challenge { word,_ in word != "ZZ" })
        XCTAssertEqual(game.scores,[0,0])
        game.play(try play(empty,"CAT"));game.skip(exchange:false)
        XCTAssertFalse(game.canChallenge)
        XCTAssertThrowsError(try game.challenge { _,_ in false })
    }
    func testFinishAndUndo() throws {
        var game=TrackedGame(names:["A","B","C"],lexicon:0)
        game.play(try play(empty,"CAT"))
        try game.finish(racks:["","qz?","b"],wentOut:0)
        XCTAssertEqual(game.scores,[33,-20,-3])
        XCTAssertTrue(game.finished);XCTAssertFalse(game.canChallenge)
        let turns=game.turns.count
        game.skip(exchange:true);game.play(try play(empty,"AT"))
        XCTAssertEqual(game.turns.count,turns)
        XCTAssertThrowsError(try game.finish(racks:["","",""],wentOut:nil))
        game.turns.removeLast();XCTAssertEqual(game.scores,[10,0,0]);XCTAssertFalse(game.finished)
        try game.finish(racks:[" a ","?","B"],wentOut:nil)
        XCTAssertEqual(game.scores,[9,0,-3])
    }
    func testInvalidFinishDoesNotMutateGame() throws {
        var game=TrackedGame(names:["A","B"],lexicon:0)
        for racks in [[""],["123",""],["AAAAAAAA",""],["é",""],["A B",""]] {
            XCTAssertThrowsError(try game.finish(racks:racks,wentOut:nil))
            XCTAssertTrue(game.turns.isEmpty)
        }
        XCTAssertThrowsError(try game.finish(racks:["A",""],wentOut:0))
        XCTAssertThrowsError(try game.finish(racks:["",""],wentOut:2))
        XCTAssertThrowsError(try game.finish(racks:["",""],wentOut:-1))
    }
}
