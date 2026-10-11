#!/usr/bin/env zsh
set -euo pipefail

# ANSI QuickLook Build Script
# Builds host application, embedded Quick Look App Extension, and packages build/ANSI QuickLook.app

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

echo "==> [2/4] Compiling ANSI QuickLook and Quick Look App Extension..."
mkdir -p build
xcodebuild -project ANSIQuickLook.xcodeproj \
    -scheme ANSIQuickLook \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    build

BUILT_APP="build/DerivedData/Build/Products/Release/ANSIQuickLook.app"
TARGET_APP="build/ANSI QuickLook.app"

echo "==> [3/4] Packaging application bundle into build/..."
rm -rf "$TARGET_APP"
cp -R "$BUILT_APP" "$TARGET_APP"

echo "==> [4/4] Applying ad-hoc codesign to extension and host..."
codesign --force --deep --sign - "$TARGET_APP/Contents/PlugIns/ANSIQuickLookPreview.appex"
codesign --force --deep --sign - "$TARGET_APP"

echo "==> Build complete: $TARGET_APP"
