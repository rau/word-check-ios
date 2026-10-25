import XCTest
@testable import WordCheckCore

final class StorageTests: XCTestCase {
    var directory:URL!
    override func setUpWithError() throws {
        directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at:directory) }
    var url:URL { directory.appendingPathComponent("nested/game.json") }
    func testMissingSaveAndAtomicOverwriteRoundTrip() throws {
        let store=GameStore(url:url);XCTAssertNil(try store.load())
        var game=TrackedGame(names:["Alex","Sam"],lexicon:0)
        game.skip(exchange:true);try store.save(game)
        game.lexicon=1;game.skip(exchange:false);try store.save(game)
        let loaded=try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.names,game.names);XCTAssertEqual(loaded.lexicon,1)
        XCTAssertEqual(loaded.turns.count,2);XCTAssertEqual(loaded.currentPlayer,0)
        XCTAssertEqual(loaded.board,game.board);XCTAssertEqual(loaded.scores,game.scores)
    }
    func testCorruptedAndStructurallyInvalidSavesThrow() throws {
        let store=GameStore(url:url)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        for data in [Data(),Data("{broken".utf8),Data("{}".utf8)] {
            try data.write(to:url);XCTAssertThrowsError(try store.load())
        }
        let invalidGames=[
            TrackedGame(names:[],lexicon:0),TrackedGame(names:["A"],lexicon:0),
            TrackedGame(names:["A","B"],lexicon:2),
            TrackedGame(names:["A","B"],lexicon:0,turns:[GameTurn(player:2,title:"Pass",placements:[],changes:[0,0],kind:"pass")]),
            TrackedGame(names:["A","B"],lexicon:0,turns:[GameTurn(player:0,title:"Pass",placements:[],changes:[],kind:"pass")]),
            TrackedGame(names:["A","B"],lexicon:0,turns:[GameTurn(player:0,title:"A",placements:[Placement(index:225,tile:Tile(letter:"A",blank:false))],changes:[1,0],kind:"play")])
        ]
        for game in invalidGames { try store.save(game);XCTAssertThrowsError(try store.load()) }
    }
    func testSaveFailurePropagates() throws {
        let blocker=directory.appendingPathComponent("file")
        try Data("x".utf8).write(to:blocker)
        XCTAssertThrowsError(try GameStore(url:blocker.appendingPathComponent("game.json")).save(TrackedGame(names:["A","B"],lexicon:0)))
    }
    func testChallengeSaveRoundTripAndLegacyOptionalFields() throws {
        var game=TrackedGame(names:["A","B"],lexicon:0)
        let play=try BoardRules.evaluate(board:game.board,word:"ZZ",start:112,vertical:false,blanks:[1],valid:{_ in true})
        game.play(play);_=try game.challenge { _,_ in false }
        let store=GameStore(url:url);try store.save(game)
        let loaded=try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.board,game.board);XCTAssertEqual(loaded.scores,[0,0]);XCTAssertEqual(loaded.currentPlayer,1)
        let legacy=Data(#"{"names":["A","B"],"lexicon":0,"turns":[{"player":0,"title":"CAT","placements":[],"changes":[10,0],"kind":"play"}]}"#.utf8)
        try legacy.write(to:url)
        var old=try XCTUnwrap(store.load());XCTAssertNil(old.turns[0].lexicon)
        XCTAssertFalse(try old.challenge { _,edition in XCTAssertEqual(edition,0);return true })
    }
}
