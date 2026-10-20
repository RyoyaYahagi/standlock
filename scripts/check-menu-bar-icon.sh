#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/standlock-icon-check.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

# Compile the real progress definitions and app renderer without an Xcode test
# target. This checks AppKit drawing; it does not assert on-screen visibility.
xcrun swiftc -module-cache-path "$TEMP_ROOT/ModuleCache" -swift-version 6 -emit-library -emit-module -module-name StandLockCore \
  -emit-module-path "$TEMP_ROOT/StandLockCore.swiftmodule" \
  "$REPO_ROOT/StandLockKit/Sources/StandLockCore/BreakProgress.swift" \
  -o "$TEMP_ROOT/libStandLockCore.dylib"
xcrun swiftc -module-cache-path "$TEMP_ROOT/ModuleCache" -swift-version 6 -parse-as-library -I "$TEMP_ROOT" -L "$TEMP_ROOT" \
  -lStandLockCore -Xlinker -rpath -Xlinker "$TEMP_ROOT" \
  "$REPO_ROOT/StandLock/Views/MenuBar/MenuBarIcon.swift" \
  "$REPO_ROOT/scripts/tests/MenuBarIconChecks.swift" \
  -o "$TEMP_ROOT/check-icon"
"$TEMP_ROOT/check-icon"
echo "PASS: ON/OFF and progress icons render nonempty template images."
