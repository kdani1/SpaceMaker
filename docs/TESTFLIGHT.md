# Internal iOS test build

The `ios-testflight` Codemagic workflow uses the existing Flutter iOS project:

- Display name: SpaceMaker; suggested Apple listing: SpaceMaker Preview.
- Bundle identifier: `app.spacemaker.swipe` (unchanged).
- Marketing version: `1.1.0`; build number allocated from Apple's latest build
  and Codemagic's project counter, rather than repeatedly uploading build 3.
- Minimum iOS: 15.0.
- Flutter 3.44.0 / Dart 3.12, locked package resolution.

App Store Connect app ID: `6811652076`; Codemagic app ID:
`6aa6e528e16b4de3f95e1312`. The numeric Apple ID is configured in the workflow.
An App Store signing profile for this bundle ID must be available through the
existing authorized Codemagic Apple integration. The first workflow step
deliberately refuses to proceed with an empty app ID.

The archive is exported for internal TestFlight testing only. It uses
`config/monetization.example.json`, which enables Google sample test ads and
contains no RevenueCat key or production ad identifiers. This does not create
store subscriptions or enable real purchases. The source behavior remains
unchanged: when purchases are unconfigured, free cleaning remains available.
Test-ad networking still contacts Google; photos/videos remain local according
to the current app implementation. Native permissions, UMP consent and media
deletion must be exercised on an iPhone with test media.

The photos permission includes deletion capabilities. Use disposable media for
the first test, inspect the selected trash items and confirm deletion only when
intended. Permission prompts and denied/limited-library handling are device
test requirements; a successful archive does not prove them.

## Validation on 2026-09-13

- Existing Node source/configuration checks: 6 passed.
- Shared TestFlight allocation/upload helper unit tests: 8 passed.
- No Flutter executable or Xcode is available in this Windows session, so
  Flutter analyze/tests and the native archive remain CI validation steps.
- Scanned 86 tracked files: no matches for common private-key, GitHub, OpenAI,
  AWS, Google API-key or Slack token patterns. This is a limited check, not a
  complete security or privacy audit. Do not treat this as public-store ready.

The upload helper verifies the IPA's embedded build number and never
automatically repeats an uncertain binary upload. Builds for the same app
should be serialized to prevent concurrent allocation races.

Official workflow reference:
[Flutter iOS deployment](https://docs.flutter.dev/deployment/ios).
