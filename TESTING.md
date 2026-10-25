# Test coverage

## Core tests (`swift test`)

| Area | Checks |
| --- | --- |
| Board geometry | All premium counts, rotation/transpose symmetry, coordinates, bounds, row wrapping, disconnected plays |
| Scoring | Opening center, every premium in both directions at all 225 squares, existing versus new premiums, blanks, crosswords, compounded word multipliers, seven-tile bonus |
| Placement validation | Invalid text/length, overwrite protection, no-new-tile plays, tile supply, maximum new tiles, invalid crosswords |
| Turn state | 2–4 player rotation, pass/exchange, undo, successful/failed challenges, recorded dictionary selection, preserved history, challenge expiry |
| Endgame | Rack deductions, went-out transfer, blank rack tiles, invalid racks/player indexes, finished-game guards, undo |
| Draft editor | Every possible crossing position in both directions, normal/blank input, consecutive board letters, backspace, selection replacement, leading existing tiles, direction changes, edge overflow |
| Persistence | Missing file, directory creation, atomic overwrite, corruption, invalid decoded state, write failure, challenge round trip, legacy optional fields |
| Dictionary | Normalization, input bounds/Unicode rejection, metadata, missing/corrupt/unreadable resources; optional real NASPA/Collins integration |

The board/draft loops exercise many cases within each XCTest method. This is behavioral coverage, not a claim of exhaustive state-space coverage.

## iOS UI tests

The shared Xcode scheme runs `CheckerTests` and `GameTests`. They cover repeated checking and dictionary switching; input errors and recovery; keyboard dismissal; sheet closing; gameplay, scorekeeping, pass/exchange/undo, restart persistence and finish; zoom/pan and double-tap direction; automatic crossings/backspace; pending and assigned blanks; challenges and retained history; mid-game dictionary switching; player setup; duplicate/default names; cancelled confirmations; invalid/cancelled blank assignments; FAQ; empty history; and iPad landscape keyboard layout.

XCTest's synthesized iPad pinch starts with narrowly separated fingers, so the test uses a wider gesture on tablets. It asserts actual tile-size changes, then fits the board again and checks direction changes do not zoom.

Visual screenshot attachments support manual inspection of selection colors, dark-mode bonuses, uppercase blank letters, and native sheet appearance. Pixel appearance, animation smoothness, VoiceOver usability, and real-device touch feel still need manual inspection; these are not proven by element-existence assertions.

## CI and reproduction

GitHub Actions runs `swift test --enable-code-coverage` on macOS without signing or private word lists. The licensed integration test skips explicitly there. Locally, point `WORDCHECK_DICTIONARY_BUNDLE` to the built app to include it.

`./scripts/test-ios.sh SIMULATOR_UDID` runs UI tests with code coverage and saves an `.xcresult` bundle under `build/`. Open that result in Xcode to inspect failures, attachments, and coverage. For core coverage, `swift test --show-codecov-path` prints the exported JSON path.

The two older `scripts/check-*.swift` runners remain available as standalone regression checks. Release submission and Apple review are deliberately outside the automated test suite.
