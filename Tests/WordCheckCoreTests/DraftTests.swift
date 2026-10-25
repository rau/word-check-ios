import XCTest
@testable import WordCheckCore

final class DraftTests: XCTestCase {
    let empty=[Tile?](repeating:nil,count:225)
    func testTypedBlankParsingAndValidation() throws {
        let parsed=try TypedPlay.parse(" A?bC \n")
        XCTAssertEqual(parsed.word,"A?BC");XCTAssertEqual(parsed.blanks,[1,2])
        for invalid in ["é","ß","A B","123","😀"] { XCTAssertThrowsError(try TypedPlay.parse(invalid)) }
        XCTAssertEqual(try TypedPlay.parse("??").blanks,[0,1])
    }
    func testAutomaticCrossingAndBackspaceEverySquareAndDirection() {
        for down in [false,true] {
            let step=down ? 15:1
            for start in 0..<225 where (down ? start/15:start%15)<13 {
                for letter in ["A","?"] {
                    var board=empty;board[start+step]=Tile(letter:"C",blank:true)
                    var draft=BoardDraft(input:letter)
                    var display=draft.display(board:board,start:start,vertical:down)
                    XCTAssertEqual(display.text,letter+"C");XCTAssertEqual(display.sources,[0,nil])
                    _=draft.edit(range:NSRange(location:2,length:0),replacement:"t",display:display)
                    display=draft.display(board:board,start:start,vertical:down)
                    XCTAssertEqual(display.text,letter+"CT")
                    _=draft.edit(range:NSRange(location:2,length:1),replacement:"",display:display)
                    display=draft.display(board:board,start:start,vertical:down)
                    XCTAssertEqual(display.text,letter+"C")
                    _=draft.edit(range:NSRange(location:1,length:1),replacement:"",display:display)
                    XCTAssertEqual(draft.input,"")
                    XCTAssertEqual(board[start+step],Tile(letter:"C",blank:true))
                }
            }
        }
    }
    func testConsecutiveExistingLettersAndSelectionReplacement() {
        var board=empty
        for (i,letter) in ["C","A","T"].enumerated() { board[112+i]=Tile(letter:letter,blank:false) }
        var draft=BoardDraft(input:"S?")
        var display=draft.display(board:board,start:111,vertical:false)
        XCTAssertEqual(display.text,"SCAT?");XCTAssertEqual(display.sources,[0,nil,nil,nil,1])
        _=draft.edit(range:NSRange(location:0,length:5),replacement:"X",display:display)
        XCTAssertEqual(draft.input,"X")
        display=draft.display(board:board,start:111,vertical:false)
        XCTAssertEqual(display.text,"XCAT")
        _=draft.edit(range:NSRange(location:0,length:0),replacement:"Y",display:display)
        XCTAssertEqual(draft.input,"YX")
    }
    func testStartingOnExistingTilesAndDirectionChange() {
        var board=empty;board[112]=Tile(letter:"C",blank:false);board[113]=Tile(letter:"A",blank:false)
        var draft=BoardDraft(input:"T")
        let display=draft.display(board:board,start:112,vertical:false)
        XCTAssertEqual(display.text,"CAT")
        XCTAssertEqual(draft.display(board:board,start:112,vertical:true).text,"CT")
        _=draft.edit(range:NSRange(location:0,length:1),replacement:"",display:display)
        XCTAssertEqual(draft.input,"T","Deleting a leading board tile must not delete new tiles after it")
        XCTAssertEqual(BoardDraft().display(board:board,start:112,vertical:false).text,"")
    }
    func testDraftDoesNotWrapAndOverflowRemainsRejectable() throws {
        var board=empty;board[15]=Tile(letter:"C",blank:false)
        let draft=BoardDraft(input:"AT")
        let display=draft.display(board:board,start:14,vertical:false)
        XCTAssertEqual(display.text,"AT")
        XCTAssertThrowsError(try BoardRules.evaluate(board:board,word:display.text,start:14,vertical:false,blanks:[],valid:{_ in true}))
    }
}
