Fastlane setup for TestFlight upload

This folder contains a minimal Fastlane configuration to upload the built IPA to TestFlight.

How it works
- Use the `upload_to_testflight` lane which uploads `build/Runner-ipa/Runner.ipa`.
- Authentication: use an App Store Connect API key (recommended) to avoid app-specific passwords.

Two ways to provide the API key
1) ASC_KEY_PATH: set this env to the path of the downloaded `AuthKey_XXXX.p8` file. Also set:
   - ASC_KEY_ID (the Key ID shown in App Store Connect)
   - ASC_ISSUER_ID (the Issuer ID shown in App Store Connect)

2) ASC_KEY (base64): set ASC_KEY to the base64-encoded contents of the `.p8` file, and also set ASC_KEY_ID and ASC_ISSUER_ID.
   Example (local):
     base64 ~/Downloads/AuthKey_ABC123.p8 | pbcopy
     export ASC_KEY=$(pbpaste)
     export ASC_KEY_ID=ABC123
     export ASC_ISSUER_ID=xxxx-xxxx-xxxx-xxxx

Running locally
1. Ensure you have fastlane installed: `gem install fastlane -NV` or use bundler.
2. Make sure `build/Runner-ipa/Runner.ipa` exists (we created it with xcodebuild + xcodebuild -exportArchive).
3. Run the helper script:
   ./ci/upload_to_testflight.sh

In CI
- Add ASC_KEY (base64) or ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID as secure environment variables.
- Run the script as part of your workflow after the archive/export step.

Security
- Do NOT commit the `.p8` file to the repo. Use CI secret storage or local environment.
