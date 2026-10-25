#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; ds=json.load(sys.stdin)["devices"].get("com.apple.CoreSimulator.SimRuntime.iOS-26-2", []); print(next(d["udid"] for d in ds if d["name"] == "Word check — iPhone 17"))')
xcodebuild -project WordCheck.xcodeproj -scheme WordCheck -configuration Debug CODE_SIGNING_ALLOWED=NO -destination "id=$DEVICE" -derivedDataPath build -parallel-testing-enabled NO test > test.log 2>&1
swiftc WordCheck/Dictionary.swift scripts/check-dictionary.swift -o build/check-dictionary
build/check-dictionary "$PWD/build/Build/Products/Debug-iphonesimulator/WordCheck.app"
swiftc WordCheck/Game.swift scripts/check-game.swift -o build/check-game
build/check-game
xcrun simctl launch "$DEVICE" com.raunak.wordcheck
