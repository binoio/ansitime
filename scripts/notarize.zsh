#!/usr/bin/env zsh
set -euo pipefail

# ANSI QuickLook Notarization Script
# Signs with Developer ID Application certificate, creates a distributable DMG/ZIP,
# submits to Apple Notary Service, and staples the notarization ticket.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP="$REPO_ROOT/build/ANSI QuickLook.app"

if [[ ! -d "$APP" ]]; then
    echo "App bundle not found at $APP. Running build.zsh first..."
    "$REPO_ROOT/scripts/build.zsh"
fi

SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-AC_PASSWORD}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "NOTE: DEVELOPER_ID_APPLICATION environment variable not set."
    echo "To perform a production signing and notarization run, execute:"
    echo "  export DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID)\""
    echo "  export NOTARY_KEYCHAIN_PROFILE=\"your-notary-keychain-profile\""
    echo "  ./scripts/notarize.zsh"
    exit 0
fi

echo "==> Deep signing extension and host app with $SIGNING_IDENTITY..."
codesign --force --options runtime --deep --sign "$SIGNING_IDENTITY" "$APP/Contents/PlugIns/ANSIQuickLookPreview.appex"
codesign --force --options runtime --deep --sign "$SIGNING_IDENTITY" "$APP"

ARCHIVE_PATH="$REPO_ROOT/build/ANSIQuickLook-Release.zip"
echo "==> Creating archive for submission: $ARCHIVE_PATH..."
ditto -c -k --keepParent "$APP" "$ARCHIVE_PATH"

echo "==> Submitting to Apple Notary Service using profile: $KEYCHAIN_PROFILE..."
xcrun notarytool submit "$ARCHIVE_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "==> Stapling notarization ticket to $APP..."
xcrun stapler staple "$APP"

echo "==> Verifying signature and Gatekeeper acceptance..."
spctl --assess --type execute --verbose "$APP"

echo "==> Notarization complete!"
