# Xcode Cloud + Flutter integration (quickstart)

This folder contains a recommended pre-build script and documentation to enable building this Flutter project on Xcode Cloud and distributing to TestFlight.

Files added
- `ci/xcode_cloud_prebuild.sh` — Pre-build script to install Flutter (if missing), run `flutter pub get`, build iOS artifacts `--no-codesign`, and run `pod install`.

How to use
1. Commit these files to your repository (already committed here).
2. Make sure the pre-build script is executable. On your machine run:

```bash
chmod +x ci/xcode_cloud_prebuild.sh
git add ci/xcode_cloud_prebuild.sh && git commit -m "ci: add xcode cloud prebuild script"
git push
```

3. Enable Xcode Cloud for the app in App Store Connect (Account Holder/Admin).
   - App Store Connect → My Apps → choose the app (or create it).
   - In Xcode (or App Store Connect), set up Xcode Cloud and connect your Git provider (GitHub/GitLab/Bitbucket).
   - Ensure the Xcode scheme `Runner` is shared in `ios/xcshareddata/xcschemes/` and committed.

4. Configure a Xcode Cloud workflow:
   - Platform: iOS
   - Scheme: Runner (Release / Archive)
   - Pre-Build: add a "Run script" step that runs `./ci/xcode_cloud_prebuild.sh`
   - Signing: allow Xcode Cloud to manage signing automatically, or configure provisioning profiles in App Store Connect.
   - Distribution: set to TestFlight (Internal) if you want automatic upload.

5. Trigger a manual build to validate. Check logs for pre-build script output.

Troubleshooting & notes
- Make sure `ios/Podfile` exists in repo; Xcode Cloud will run `pod install` but initial Podfile must be present.
- If you use private packages/submodules, give Xcode Cloud access to those repositories.
- For signing issues: confirm App Bundle ID in `ios/Runner/Info.plist` matches the App record in App Store Connect.
- Consider caching Flutter and CocoaPods on Xcode Cloud to speed up builds.

Security and access
- Do NOT share Apple ID passwords in chat. Add users through App Store Connect → Users and Access with role "App Manager" or "Developer" if you want me to perform App Store Connect tasks on your behalf.

If you want me to continue and fully manage the publish process, please choose one of the following and act accordingly:

- Option A (recommended, full remote help): Add a user in App Store Connect with role "App Manager" and let me know the invited email (I will not ask for the password). Once the invite is accepted I can finalize Xcode Cloud setup, trigger builds, and manage TestFlight.
- Option B (no App Store access): I run the build locally on this machine and produce an IPA which you or your admin upload to App Store Connect.
- Option C (you keep control): I guide you step-by-step while you perform the App Store Connect and Xcode Cloud admin actions.

Next steps (what I can do now)
1. I can commit additional CI docs or small config if you want more automation.
2. If you select Option B, confirm and I will run `flutter pub get && flutter build ios --no-codesign` locally and prepare the artifact.
3. If you select Option A, please invite a user in App Store Connect and tell me when the invite is accepted (email address of the invited user). I will then configure Xcode Cloud workflow if repo access is granted.

Questions? Reply with which Option (A/B/C) you choose and I will proceed.
