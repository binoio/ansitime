#!/usr/bin/env bash
set -e

# Xcode Cloud CI/CD Post-Clone Hook
echo "==> Xcode Cloud: Installing xcodegen via Homebrew..."
brew install xcodegen

echo "==> Xcode Cloud: Generating Xcode project..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
