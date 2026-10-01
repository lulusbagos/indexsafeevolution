#!/bin/bash
set -euo pipefail

# ci/upload_to_testflight.sh
# Usage: set App Store Connect API key either as ASC_KEY_PATH (path to .p8) or
# set ASC_KEY (base64-encoded contents of the .p8), ASC_KEY_ID and ASC_ISSUER_ID.
# Then run this script from repo root. It expects the IPA to be at build/Runner-ipa/Runner.ipa

echo "Preparing to upload IPA to TestFlight using fastlane"

if ! command -v bundle >/dev/null 2>&1 && ! command -v fastlane >/dev/null 2>&1; then
  echo "fastlane not found. Install with: gem install fastlane -NV  OR use bundler: bundle install" >&2
  exit 1
fi

IPA_PATH=${IPA_PATH:-build/Runner-ipa/Runner.ipa}
if [ ! -f "$IPA_PATH" ]; then
  echo "IPA not found at $IPA_PATH" >&2
  exit 1
fi

echo "Uploading $IPA_PATH to TestFlight..."
fastlane ios upload_to_testflight

echo "Upload finished (check App Store Connect processing)."
