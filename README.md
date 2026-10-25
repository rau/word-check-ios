# Word Check: Board & Scores

A free, offline iPhone and iPad companion for physical word-tile games. Built with Swift and native UIKit components for iOS 26, including Liquid Glass controls.

- Standard 15 × 15 board with pinch zoom, panning, and automatic scoring.
- Two to four players, pass/exchange, undo, history, and final rack adjustments.
- Type only new tiles; existing letters are included automatically. `?` places a blank whose letter is assigned on Play.
- Double-tap the selected square to change typing direction.
- Challenge the previous play without showing dictionary hints during normal tracking.
- NASPA/Collins selection, including mid-game switching, and a separate closable word checker.
- Native FAQ sheet, local game persistence, and no accounts, ads, analytics, or purchases.

## Build

Requires Xcode with the iOS 26 SDK and an iOS 26 simulator/device.

1. Add your licensed dictionary files as described in [WordCheck/Data/README.md](WordCheck/Data/README.md).
2. Open `WordCheck.xcodeproj` and select the `WordCheck` scheme.
3. Choose an iPhone or iPad simulator and Run. For a physical device, choose your development team and a bundle identifier you control in Signing & Capabilities.

The Xcode project and shared scheme are committed; no project generator is required. `scripts/generate_project.rb` is an optional maintainer utility using the `xcodeproj` Ruby gem.

## Tests

Run the portable model, editing, persistence, and dictionary-input tests without licensed data:

```sh
swift test --enable-code-coverage
```

The one licensed-dictionary integration test explicitly skips when resources are unavailable. To run it against the actual dictionaries in a built app:

```sh
WORDCHECK_DICTIONARY_BUNDLE="/absolute/path/to/WordCheck.app" swift test --enable-code-coverage
```

Run the complete iOS UI suite on a chosen iOS 26 simulator:

```sh
xcrun simctl list devices available
./scripts/test-ios.sh YOUR_SIMULATOR_UDID
```

Run on both iPhone and iPad for layout and gesture coverage. Tests create/reset a **simulator** game; use a dedicated test simulator. Screenshots and result bundles stay in the ignored `build/` directory. See [TESTING.md](TESTING.md) for the test matrix and limitations.

GitHub Actions runs the core suite on every push and pull request. Licensed data, signing materials, device receipts, and App Store account metadata are not included in this repository. UI tests run locally because they require the licensed word lists.

## Structure

- `WordCheck/Game.swift`: board rules, scoring, turns, challenges, persistence, draft editing.
- `WordCheck/Dictionary.swift`: dictionary loading and checker input validation.
- `WordCheck/GameController.swift`: native gameplay, setup, history, FAQ, and endgame forms.
- `WordCheck/BoardView.swift`: board drawing, accessibility, selection and pinch gestures.
- `WordCheck/App.swift`: app lifecycle and standalone checker.
- `Tests/WordCheckCoreTests`: SwiftPM unit/integration tests.
- `WordCheckUITests`: XCTest user-flow regression tests.

The bundled dictionaries are separately licensed and are not part of the public source distribution. This is an independent companion app, not an official product of the board game's trademark owners.
