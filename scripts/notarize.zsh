#!/usr/bin/env zsh
set -euo pipefail

# ANSITime Notarization Script
# Signs with Developer ID Application certificate, creates a distributable archive,
# submits to Apple Notary Service, staples the notarization ticket, and updates the release zip.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP="$REPO_ROOT/build/ANSITime.app"

# Always rebuild to ensure fresh binaries and Info.plist
echo "==> Building fresh application bundle..."
"$REPO_ROOT/scripts/build.zsh"

# Determine Developer ID signing identity
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application:" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "Error: No 'Developer ID Application' signing identity found." >&2
    echo "To configure manually: export DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID)\"" >&2
    exit 1
fi

# Determine Notarytool keychain profile
KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
if [[ -z "$KEYCHAIN_PROFILE" ]]; then
    if xcrun notarytool history --keychain-profile FF_NOTARY_PROFILE >/dev/null 2>&1; then
        KEYCHAIN_PROFILE="FF_NOTARY_PROFILE"
    elif xcrun notarytool history --keychain-profile AC_PASSWORD >/dev/null 2>&1; then
        KEYCHAIN_PROFILE="AC_PASSWORD"
    else
        KEYCHAIN_PROFILE="FF_NOTARY_PROFILE"
    fi
fi

echo "==> Using Signing Identity: $SIGNING_IDENTITY"
echo "==> Using Notary Keychain Profile: $KEYCHAIN_PROFILE"

# Inside-out signing
echo "==> Signing Sparkle framework components..."
SPARKLE_DIR="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
if [[ -d "$SPARKLE_DIR" ]]; then
    if [[ -d "$SPARKLE_DIR/XPCServices/Downloader.xpc" ]]; then
        codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$SPARKLE_DIR/XPCServices/Downloader.xpc"
    fi
    if [[ -d "$SPARKLE_DIR/XPCServices/Installer.xpc" ]]; then
        codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$SPARKLE_DIR/XPCServices/Installer.xpc"
    fi
    if [[ -f "$SPARKLE_DIR/Autoupdate" ]]; then
        codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$SPARKLE_DIR/Autoupdate"
    fi
    if [[ -d "$SPARKLE_DIR/Updater.app" ]]; then
        codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$SPARKLE_DIR/Updater.app"
    fi
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP/Contents/Frameworks/Sparkle.framework"
fi

echo "==> Signing ANSITimeQuickLook extension..."
codesign --force --options runtime \
    --entitlements "$REPO_ROOT/Sources/ANSITimeQuickLook/ANSITimeQuickLook.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$APP/Contents/PlugIns/ANSITimeQuickLook.appex"

echo "==> Signing ANSITime host application..."
codesign --force --options runtime \
    --entitlements "$REPO_ROOT/Sources/ANSITime/ANSITime.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$APP"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP"

SUBMISSION_ZIP="$REPO_ROOT/build/ANSITime-submission.zip"
echo "==> Creating temporary archive for notarytool submission..."
rm -f "$SUBMISSION_ZIP"
ditto -c -k --keepParent "$APP" "$SUBMISSION_ZIP"

echo "==> Submitting to Apple Notary Service (waiting for completion)..."
xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait
rm -f "$SUBMISSION_ZIP"

echo "==> Stapling notarization ticket to $APP..."
xcrun stapler staple "$APP"

echo "==> Verifying Gatekeeper acceptance with spctl..."
spctl --assess --type execute --verbose "$APP"

# Extract version from Info.plist
VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
RELEASE_ZIP="$REPO_ROOT/build/ANSITime-${VERSION}.zip"
echo "==> Creating final notarized release zip: $RELEASE_ZIP..."
rm -f "$RELEASE_ZIP"
ditto -c -k --keepParent "$APP" "$RELEASE_ZIP"

echo "==> Notarization and packaging complete: $RELEASE_ZIP"
