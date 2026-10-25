import Foundation
@main struct GameChecks {
 static func main() throws {
  var checks=0
  func expect(_ value:Bool,_ title:String){checks += 1;if !value {fatalError(title)}}
  let empty=[Tile?](repeating:nil,count:225)
  func play(_ board:[Tile?],_ word:String,_ start:Int,_ down:Bool=false,_ blanks:Set<Int>=[]) throws -> PlayResult {try BoardRules.evaluate(board:board,word:word,start:start,vertical:down,blanks:blanks){_ in true}}
  func rejects(_ title:String,_ body:() throws -> Void){do{try body();fatalError("Expected rejection: \(title)")}catch{checks += 1}}
  expect((0..<225).filter{BoardRules.premium($0) == .tripleWord}.count == 8,"8 TW")
  expect((0..<225).filter{BoardRules.premium($0) == .doubleWord}.count == 17,"17 DW")
  expect((0..<225).filter{BoardRules.premium($0) == .doubleLetter}.count == 24,"24 DL")
  expect((0..<225).filter{BoardRules.premium($0) == .tripleLetter}.count == 12,"12 TL")
  var game=TrackedGame(names:["A","B"],lexicon:0)
  let cat=try play(empty,"CAT",112);expect(cat.score==10,"Center doubles CAT");game.play(cat)
  let at=try play(game.board,"AT",113,true);expect(at.score==3,"Existing center not doubled");game.play(at)
  expect(game.scores == [10,3],"Scores and turn rotation");expect(game.currentPlayer==0,"Two turns")
  rejects("Overwrite"){_ = try play(game.board,"DOG",112)}
  rejects("Disconnected"){_ = try play(game.board,"DOG",0)}
  rejects("First must center"){_ = try play(empty,"CAT",0)}
  rejects("Off edge"){_ = try play(empty,"CAT",119)}
  rejects("More than seven"){_ = try play(empty,"RELATION",112)}
  rejects("No new tiles"){_ = try play(game.board,"CAT",112)}
  rejects("Single first tile"){_ = try play(empty,"A",112)}
  rejects("Non-ASCII"){_ = try play(empty,"é",112)}
  rejects("Dictionary rejection"){_ = try BoardRules.evaluate(board:empty,word:"ZZ",start:112,vertical:false,blanks:[]){_ in false}}
  expect(try play(empty,"CAT",112,false,[0]).score == 4,"Blank zero on DW")
  expect(try play(empty,"READING",109).score == 68,"Seven tiles plus center and DL")
  var cross=empty;cross[111]=Tile(letter:"A",blank:false);cross[97]=Tile(letter:"A",blank:false)
  let doubleCross=try play(cross,"T",112);expect(doubleCross.words.count==2 && doubleCross.score==8,"DW applies both directions")
  rejects("Invalid cross word"){_ = try BoardRules.evaluate(board:cross,word:"T",start:112,vertical:false,blanks:[]){$0 != "AT"}}
  var edges=empty;edges[119]=Tile(letter:"A",blank:false)
  rejects("Horizontal row must not wrap"){_ = try play(edges,"AT",119)}
  var blanksBoard=empty;blanksBoard[112]=Tile(letter:"A",blank:true)
  expect(try play(blanksBoard,"AT",112).score==1,"Existing blank remains zero")
  rejects("Supply"){_ = try play(empty,"QQ",112)}
  expect(try play(empty,"QQ",112,false,[1]).score==20,"Blank solves supply")
  game.skip(exchange:false);expect(game.currentPlayer==1,"Pass changes turn");game.skip(exchange:true);expect(game.currentPlayer==0,"Exchange changes turn")
  game.lexicon=1;expect(game.scores == [10,3],"Switching dictionary preserves scores");expect(game.turns.first?.lexicon==0,"Each play records dictionary");
  let encoded=try JSONEncoder().encode(game);let restored=try JSONDecoder().decode(TrackedGame.self,from:encoded)
  expect(restored.board==game.board && restored.scores==game.scores && restored.lexicon==1,"Persistence round trip")
  try game.finish(racks:["","QZ?"],wentOut:0);expect(game.scores == [30,-17],"Endgame transfer");expect(game.finished,"Finished state")
  game.turns.removeLast();expect(game.scores == [10,3] && !game.finished,"Undo finish")
  game.turns.removeLast();expect(game.currentPlayer==1,"Undo exchange")
  rejects("Invalid rack"){try game.finish(racks:["123",""],wentOut:nil)}
  rejects("Not actually out"){try game.finish(racks:["A",""],wentOut:0)}
  try game.finish(racks:["A","B"],wentOut:nil);expect(game.scores == [9,0],"Stalemate deductions")
  var challengeGame=TrackedGame(names:["A","B","C"],lexicon:0)
  let phony=try play(empty,"ZZ",112,false,[1]); challengeGame.play(phony)
  expect(challengeGame.canChallenge,"Previous play challengeable")
  challengeGame.lexicon=1
  var usedLexicon = -1
  let won=try challengeGame.challenge { _,edition in usedLexicon=edition; return false }
  expect(won && usedLexicon == 0,"Challenge uses play dictionary")
  expect(challengeGame.board == empty && challengeGame.scores == [0,0,0],"Challenge removes blanks and reverses points")
  expect(challengeGame.currentPlayer == 1 && !challengeGame.canChallenge,"Successful challenger retains turn; no repeated challenge")
  expect(challengeGame.turns.first?.title == "ZZ","History retains original play")
  let saved=try JSONDecoder().decode(TrackedGame.self,from:JSONEncoder().encode(challengeGame))
  expect(saved.board == empty && saved.currentPlayer == 1,"Challenge persistence")
  challengeGame.turns.removeLast()
  expect(challengeGame.board[113]?.blank == true && challengeGame.scores[0] == phony.score,"Undo challenge restores tiles and points")
  let lost=try challengeGame.challenge { _,_ in true }
  expect(!lost && challengeGame.currentPlayer == 2,"Failed challenge skips challenger in multiplayer")
  expect(challengeGame.board[112] != nil && challengeGame.scores[0] == phony.score,"Failed challenge preserves play")
  rejects("Repeated challenge"){_ = try challengeGame.challenge { _,_ in false }}
  var crossing=TrackedGame(names:["A","B"],lexicon:0)
  crossing.play(cat); let extended=try play(crossing.board,"AT",113,true); crossing.play(extended)
  _ = try crossing.challenge { _,_ in false }
  expect(crossing.board == {var b=empty;for p in cat.placements {b[p.index]=p.tile};return b}(),"Challenge preserves old intersecting tiles")
  expect(crossing.scores == [10,0],"Challenge reverses only challenged score")
  let typed=try TypedPlay.parse("C??")
  expect(typed.word == "C??" && typed.blanks == [1,2],"Each question mark consumes a blank square")
  let assigned=try TypedPlay.parse("Cat")
  expect(try play(empty,assigned.word,112,false,assigned.blanks).score == 6,"Assigned blanks score zero")
  expect(try TypedPlay.parse(" CAT ").blanks.isEmpty,"Normal words unchanged")
  expect(try TypedPlay.parse("CA?").blanks == [2],"Trailing blank is a tile")
  expect(try TypedPlay.parse("??A").blanks == [0,1],"Consecutive blanks are tiles")
  rejects("Malformed marked input"){_ = try TypedPlay.parse("C?1T")}
  var entryBoard=empty;entryBoard[113]=Tile(letter:"A",blank:false);entryBoard[114]=Tile(letter:"T",blank:true)
  var entry=BoardDraft(input:"C")
  var shown=entry.display(board:entryBoard,start:112,vertical:false)
  expect(shown.text == "CAT","Typing fills consecutive board letters")
  _ = entry.edit(range:NSRange(location:3,length:0),replacement:"S",display:shown)
  shown=entry.display(board:entryBoard,start:112,vertical:false)
  expect(shown.text == "CATS","Continues after existing letters")
  _ = entry.edit(range:NSRange(location:3,length:1),replacement:"",display:shown)
  shown=entry.display(board:entryBoard,start:112,vertical:false)
  expect(shown.text == "CAT","Backspace deletes last new tile")
  _ = entry.edit(range:NSRange(location:2,length:1),replacement:"",display:shown)
  expect(entry.input.isEmpty && entry.display(board:entryBoard,start:112,vertical:false).text.isEmpty,"Backspace skips existing run and removes own tile")
  expect(entryBoard[114]?.blank == true,"Editing preserves existing blank")
  entry=BoardDraft(input:"?");shown=entry.display(board:entryBoard,start:112,vertical:false)
  _ = entry.edit(range:NSRange(location:2,length:1),replacement:"",display:shown)
  expect(entry.input.isEmpty,"Backspace removes standalone blank")
  var downBoard=empty;downBoard[112]=Tile(letter:"C",blank:false)
  expect(BoardDraft(input:"AT").display(board:downBoard,start:97,vertical:true).text == "ACT","Vertical intersection autofill")
  expect(BoardDraft(input:"AT").display(board:downBoard,start:112,vertical:false).text == "CAT","Start on existing tile")
  var edgeBoard=empty;edgeBoard[120]=Tile(letter:"A",blank:false)
  expect(BoardDraft(input:"T").display(board:edgeBoard,start:119,vertical:false).text == "T","Autofill does not wrap rows")
  entry=BoardDraft(input:"CS");shown=entry.display(board:entryBoard,start:112,vertical:false)
  _ = entry.edit(range:NSRange(location:0,length:shown.sources.count),replacement:"B",display:shown)
  expect(entry.display(board:entryBoard,start:112,vertical:false).text == "BAT","Select-all replacement preserves board letters")
  entry=BoardDraft(input:"?");shown=entry.display(board:downBoard,start:97,vertical:true)
  expect(shown.text == "?C","Blank advances into vertical existing letter")
  _ = entry.edit(range:NSRange(location:2,length:0),replacement:"T",display:shown)
  shown=entry.display(board:downBoard,start:97,vertical:true)
  expect(shown.text == "?CT","Next letter follows intersection")
  _ = entry.edit(range:NSRange(location:2,length:1),replacement:"",display:shown)
  shown=entry.display(board:downBoard,start:97,vertical:true)
  expect(shown.text == "?C","Delete new letter without deleting blank")
  _ = entry.edit(range:NSRange(location:1,length:1),replacement:"",display:shown)
  expect(entry.input.isEmpty,"Backspace across intersection deletes question mark")
  print("PASS: \(checks) board, scoring, blank, turn, endgame and persistence checks")
 }
}
