#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-26-2
if [[ $# -gt 0 ]]; then
  DEVICE="$1"
else
  DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; ds=json.load(sys.stdin)["devices"].get("com.apple.CoreSimulator.SimRuntime.iOS-26-2", []); print(next((d["udid"] for d in ds if d["name"] == "Word check — iPhone 17"), ""))')
  if [[ -z "$DEVICE" ]]; then
    DEVICE=$(xcrun simctl create 'Word check — iPhone 17' com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$RUNTIME")
  fi
fi
xcodebuild -project WordCheck.xcodeproj -scheme WordCheck -configuration Debug CODE_SIGNING_ALLOWED=NO -destination "id=$DEVICE" -derivedDataPath build build > build.log 2>&1
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" build/Build/Products/Debug-iphonesimulator/WordCheck.app
xcrun simctl terminate "$DEVICE" com.raunak.wordcheck 2>/dev/null || true
xcrun simctl launch "$DEVICE" com.raunak.wordcheck
open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
