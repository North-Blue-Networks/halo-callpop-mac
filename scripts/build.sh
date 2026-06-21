#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/HaloCallPop.xcodeproj"
SCHEME="HaloCallPop"
CONFIG="${1:-Release}"

cd "$ROOT"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  build

APP_PATH="$ROOT/build/DerivedData/Build/Products/$CONFIG/halo-callpop-mac.app"
if [[ -d "$APP_PATH" ]]; then
  echo "Built: $APP_PATH"
else
  echo "Build finished but app bundle not found at expected path." >&2
  exit 1
fi
