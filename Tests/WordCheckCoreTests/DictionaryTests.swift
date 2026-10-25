import XCTest
@testable import WordCheckCore

final class DictionaryTests: XCTestCase {
    func testNormalizeAndInputBoundaries() {
        XCTAssertEqual(WordDictionary.normalize(" \tqI\n"),"QI")
        for valid in ["aa","ABCDEFGHIJKLMNOP".dropLast().description," \nhello\t"] { XCTAssertNil(WordDictionary.inputError(valid)) }
        for invalid in [""," ","a",String(repeating:"A",count:16),"two words","can't","é","ß","１２","123","😀","?","A-B"] {
            XCTAssertNotNil(WordDictionary.inputError(invalid),invalid)
        }
    }
    func testLexiconMetadata() {
        XCTAssertEqual(Lexicon.allCases.count,2)
        XCTAssertEqual(Lexicon.naspa.resource,"NWL2023")
        XCTAssertEqual(Lexicon.collins.resource,"CSW24")
        XCTAssertEqual(Lexicon.naspa.title,"NASPA")
        XCTAssertEqual(Lexicon.collins.title,"Collins")
        XCTAssertTrue(Lexicon.naspa.detail.contains("2023"))
        XCTAssertTrue(Lexicon.collins.detail.contains("2024"))
    }
    func testMissingCorruptAndUnreadableResourcesFailClosed() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".bundle")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let bundle=try XCTUnwrap(Bundle(path:root.path))
        XCTAssertThrowsError(try WordDictionary(bundle:bundle))
        try "CAT\nCAT\n".write(to:root.appendingPathComponent("NWL2023.txt"),atomically:true,encoding:.utf8)
        XCTAssertThrowsError(try WordDictionary(bundle:bundle))
        try Data([0xff,0xfe,0xff]).write(to:root.appendingPathComponent("NWL2023.txt"))
        XCTAssertThrowsError(try WordDictionary(bundle:bundle))
    }
    func testLicensedDictionaryIntegration() throws {
        guard let path=ProcessInfo.processInfo.environment["WORDCHECK_DICTIONARY_BUNDLE"] else {
            throw XCTSkip("Set WORDCHECK_DICTIONARY_BUNDLE to a built app containing licensed dictionaries.")
        }
        let dictionary=try WordDictionary(bundle:XCTUnwrap(Bundle(path:path)))
        for lexicon in Lexicon.allCases {
            for word in ["QI","ZA","HELLO","SCRABBLE","AA"," qi\n"] { XCTAssertTrue(dictionary.contains(word,in:lexicon)) }
            for word in ["ZZZZ","XYZZZZ","A","NOTAWORDXYZ"] { XCTAssertFalse(dictionary.contains(word,in:lexicon)) }
        }
        XCTAssertFalse(dictionary.contains("CH",in:.naspa));XCTAssertTrue(dictionary.contains("CH",in:.collins))
    }
}
