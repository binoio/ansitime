#!/usr/bin/env zsh
set -euo pipefail

# ANSI QuickLook Run & Registration Script
# Builds, installs to /Applications, registers with LaunchServices and pluginkit, resets quicklookd, and launches.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

"$REPO_ROOT/scripts/build.zsh"

APP="$REPO_ROOT/build/ANSI QuickLook.app"

# Prefer system /Applications for full App Extension integration
TARGET_DIR="/Applications"
if [[ ! -w "$TARGET_DIR" ]]; then
    TARGET_DIR="$HOME/Applications"
fi
mkdir -p "$TARGET_DIR"
INSTALLED_APP="$TARGET_DIR/ANSI QuickLook.app"

echo "==> Installing to $INSTALLED_APP..."
rm -rf "$INSTALLED_APP"
cp -R "$APP" "$INSTALLED_APP"

echo "==> Registering with macOS LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$INSTALLED_APP"

echo "==> Registering Quick Look extension with pluginkit..."
pluginkit -a "$INSTALLED_APP/Contents/PlugIns/ANSIQuickLookPreview.appex" || true
pluginkit -e use -i io.bino.ansi-quicklook.preview || true

echo "==> Resetting quicklookd cache..."
qlmanage -r
qlmanage -r cache

echo "==> Launching ANSI QuickLook..."
open "$INSTALLED_APP"

echo "==> Ready! Highlight any .ans or .asc file in Finder and press Spacebar to preview."
