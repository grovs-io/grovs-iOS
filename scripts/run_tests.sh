#!/bin/bash
#
# Builds and runs the Grovs iOS SDK tests via SPM.
#
# The Xcode project (.xcodeproj) doesn't include the test target,
# so we temporarily hide it so xcodebuild picks up Package.swift instead.
#
# Usage:
#   ./scripts/run_tests.sh            # run all tests
#   ./scripts/run_tests.sh EventTests # run a specific test class

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCODEPROJ="$PROJECT_DIR/Grovs.xcodeproj"
XCODEPROJ_BAK="$PROJECT_DIR/Grovs.xcodeproj.bak"

# Find an available iPhone simulator
SIMULATOR_ID=$(xcrun simctl list devices available -j 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable') and 'iPhone' in d.get('name', ''):
            print(d['udid'])
            sys.exit(0)
print('')
" 2>/dev/null)

if [ -z "$SIMULATOR_ID" ]; then
    echo "Error: No available iPhone simulator found."
    echo "Install one via: xcodebuild -downloadPlatform iOS"
    exit 1
fi

echo "Using simulator: $SIMULATOR_ID"

# Build the test filter flag if a class name was provided
ONLY_TESTING=""
if [ -n "${1:-}" ]; then
    ONLY_TESTING="-only-testing:grovs-iosTests/$1"
    echo "Running only: $1"
fi

# Ensure we always restore the xcodeproj, even on failure
cleanup() {
    if [ -d "$XCODEPROJ_BAK" ]; then
        rm -rf "$XCODEPROJ"
        mv "$XCODEPROJ_BAK" "$XCODEPROJ"
    fi
}
trap cleanup EXIT

# Hide xcodeproj so xcodebuild uses Package.swift
if [ -d "$XCODEPROJ" ]; then
    mv "$XCODEPROJ" "$XCODEPROJ_BAK"
fi

# Build and test
xcodebuild test \
    -scheme Grovs \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    $ONLY_TESTING \
    2>&1 | tee /dev/stderr | tail -5

echo ""
echo "Done."
