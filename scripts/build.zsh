#!/usr/bin/env zsh
set -euo pipefail

# ANSITime Build Script
# Builds host application, embedded Quick Look App Extension, and packages build/ANSITime.app

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> [1/4] Generating Xcode project with xcodegen..."
if ! command -v xcodegen &>/dev/null; then
    if [[ -x "$HOME/.homebrew/bin/xcodegen" ]]; then
        export PATH="$HOME/.homebrew/bin:$PATH"
    elif command -v mise &>/dev/null; then
        eval "$(mise activate zsh)"
    fi
fi
xcodegen generate

echo "==> [2/4] Compiling ANSITime and ANSITime QuickLook App Extension..."
mkdir -p build
xcodebuild -project ANSITime.xcodeproj \
    -scheme ANSITime \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    build

BUILT_APP="build/DerivedData/Build/Products/Release/ANSITime.app"
TARGET_APP="build/ANSITime.app"

echo "==> [3/4] Packaging application bundle into build/..."
rm -rf "$TARGET_APP"
cp -R "$BUILT_APP" "$TARGET_APP"

echo "==> [4/4] Applying ad-hoc codesign to extension and host..."
codesign --force --deep --entitlements Sources/ANSITimeQuickLook/ANSITimeQuickLook.entitlements --sign - "$TARGET_APP/Contents/PlugIns/ANSITimeQuickLook.appex"
codesign --force --deep --entitlements Sources/ANSITime/ANSITime.entitlements --sign - "$TARGET_APP"

echo "==> Build complete: $TARGET_APP"
