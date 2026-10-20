#!/bin/bash
set -euo pipefail

# Personal, ad-hoc signed installation. Distribution signing is unchanged.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
DESTINATION="${1:-/Applications/StandLock.app}"
DESTINATION_PARENT="$(dirname "$DESTINATION")"
if [ "$(basename "$DESTINATION")" != "StandLock.app" ]; then
  echo "Usage: $0 [/path/to/StandLock.app]" >&2
  exit 1
fi
BUILD_ROOT="$REPO_ROOT/build/local"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/standlock-local.XXXXXX")"
STAGING_ROOT=""
trap 'rm -rf "$TEMP_ROOT"; if [ -n "$STAGING_ROOT" ]; then rm -rf "$STAGING_ROOT"; fi' EXIT

if /bin/ps -axo command= | /usr/bin/awk '
  /\/StandLock\.app\/Contents\/MacOS\/StandLock( |$)/ { found = 1 }
  END { exit !found }
'; then
  echo "Quit StandLock before replacing the installed app." >&2
  exit 1
fi

# Ad-hoc signatures have no Team ID, so hardened runtime cannot match Sparkle
# to the app. Apply the exception only to this temporary local-build entitlement.
cp "$REPO_ROOT/StandLock/StandLock.entitlements" "$TEMP_ROOT/Local.entitlements"
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.disable-library-validation bool true' \
  "$TEMP_ROOT/Local.entitlements"

xcodebuild -project "$REPO_ROOT/StandLock.xcodeproj" -scheme StandLock \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_ROOT" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGN_ENTITLEMENTS="$TEMP_ROOT/Local.entitlements" build

BUILT_APP="$BUILD_ROOT/Build/Products/Release/StandLock.app"
/usr/bin/codesign --verify --deep --strict "$BUILT_APP"
mkdir -p "$DESTINATION_PARENT"
STAGING_ROOT="$(mktemp -d "$DESTINATION_PARENT/.standlock-install.XXXXXX")"
/usr/bin/ditto "$BUILT_APP" "$STAGING_ROOT/StandLock.app"
/usr/bin/codesign --verify --deep --strict "$STAGING_ROOT/StandLock.app"

if [ -e "$DESTINATION" ]; then
  mv "$DESTINATION" "$STAGING_ROOT/Previous.app"
fi
if ! mv "$STAGING_ROOT/StandLock.app" "$DESTINATION"; then
  if [ -e "$STAGING_ROOT/Previous.app" ]; then
    mv "$STAGING_ROOT/Previous.app" "$DESTINATION"
  fi
  exit 1
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$DESTINATION"
echo "Installed: $DESTINATION"
"$REPO_ROOT/scripts/check-local-launch.sh" "$DESTINATION"
