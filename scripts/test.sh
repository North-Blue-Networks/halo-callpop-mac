#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Running HaloCallPop self-tests..."
swift run HaloCallPopSelfTest

if command -v xcodebuild >/dev/null 2>&1; then
  echo "Running XCTest suite..."
  xcodebuild test \
    -scheme HaloCallPop \
    -destination 'platform=macOS' \
    -only-testing:HaloCallPopTests 2>/dev/null || swift test
else
  echo "Xcode not installed — skipped XCTest (self-tests passed)."
fi
