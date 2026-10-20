#!/bin/bash
set -euo pipefail

# Exercise LaunchServices, then check the executable rather than open's exit code.
APP_PATH="${1:-/Applications/StandLock.app}"
APP_PATH="$(cd "$APP_PATH" && pwd -P)"
EXECUTABLE="$APP_PATH/Contents/MacOS/StandLock"

/usr/bin/open -a "$APP_PATH"
for _ in 1 2 3 4 5; do
  sleep 1
done

if /bin/ps -axo command= | /usr/bin/awk -v executable="$EXECUTABLE" '
  $0 == executable || index($0, executable " ") == 1 { found = 1 }
  END { exit !found }
'; then
  echo "PASS: StandLock is still running five seconds after launch."
else
  echo "FAIL: StandLock did not stay running. Check ~/Library/Logs/DiagnosticReports/StandLock-*.ips." >&2
  exit 1
fi
