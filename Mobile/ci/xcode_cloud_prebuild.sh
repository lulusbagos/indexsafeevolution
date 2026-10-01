#!/bin/bash
set -euo pipefail

# ci/xcode_cloud_prebuild.sh
# Pre-build script for Xcode Cloud to build Flutter iOS artifacts before Xcode Archive
# Usage: add this script to Xcode Cloud pre-build step. Ensure file is executable.

echo "===> Starting Xcode Cloud pre-build script for Flutter"

# Detect workspace root. Xcode Cloud sets CI_WORKSPACE env; fallback to repo root
REPO_ROOT=${CI_WORKSPACE:-$(pwd)}
echo "Repo root: $REPO_ROOT"

# Configure Flutter SDK location. If FLUTTER_HOME is set in environment, use it.
FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Flutter SDK not found at $FLUTTER_DIR — cloning stable channel (shallow)"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  git clone --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Flutter version: $(flutter --version 2>/dev/null || echo 'not available yet')"

# Use stable channel to avoid CI surprises
flutter channel stable || true
flutter upgrade --force || true

cd "$REPO_ROOT"

echo "Running flutter pub get"
flutter pub get

echo "Building iOS (no codesign)"
# Build iOS artifacts without codesign; xcodebuild will archive later
flutter build ios --no-codesign --no-sound-null-safety

echo "Installing CocoaPods"
cd ios
if command -v pod >/dev/null 2>&1; then
  pod install --repo-update || pod install
else
  echo "CocoaPods not found in PATH. Xcode Cloud should have CocoaPods installed by default."
fi

echo "Pre-build script finished"
