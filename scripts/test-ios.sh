#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 1 ]]; then
  echo "Usage: $0 SIMULATOR_UDID (see xcrun simctl list devices available)" >&2
  exit 2
fi
for resource in NWL2023 CSW24; do
  [[ -f "WordCheck/Data/$resource.txt" ]] || { echo "Missing licensed resource: $resource.txt (see WordCheck/Data/README.md)" >&2; exit 1; }
done
mkdir -p build
result="build/UITests-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project WordCheck.xcodeproj -scheme WordCheck \
  -destination "platform=iOS Simulator,id=$1" \
  -derivedDataPath build/TestDerivedData -resultBundlePath "$result" \
  -parallel-testing-enabled NO -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO test
