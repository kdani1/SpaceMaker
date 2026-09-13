# Verification — 2026-09-13

## Passed

- Real Pub resolution of `pubspec.yaml`; updated `pubspec.lock` with `purchases_flutter 10.12.0`, `google_mobile_ads 9.1.0`, `url_launcher 6.3.2` and their transitive dependencies.
- Dart/Flutter frontend compilation of `lib/main.dart` and its imported app/plugin Dart code. Final check includes AOT type-flow transformation. Kernel generated with zero reported errors. This is **not** a native APK build or a complete lint check.
- Frontend compilation of all 9 Flutter test definitions (7 entitlement cases, 1 paywall widget case, 1 existing theme case) with zero reported errors. This checks test source types; it does **not** execute Flutter widget tests.
- `node --test tool/project.test.mjs`: **6 passed, 0 failed**. Checks regional pricing data, removed server/fake billing entrypoints, native identifiers/ad metadata, iOS raster dimensions, unsafe-release rejection and checkout source invariants. These are static/project checks, not a simulation of real billing/ads.
- `node tool/check_release.mjs config/monetization.example.json` correctly rejects the non-production config: test ads, absent provider config/legal URLs, Google sample app IDs and inherited debug signing.

## Blocked / not executed

- `android_build_apk`: native SDK lacks `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.3.1`; build stopped before a new APK existed. Do not remove or replace the ad/billing dependencies to bypass this.
- No Xcode/macOS build, iOS archive, store upload, price publication, purchase or real ad impression.
- Full `flutter analyze`, `flutter test` and device visual verification have not run. This Android environment has a specialized AOT SDK, not the normal Flutter CLI/test runner. A standalone quota smoke attempt also could not execute because the Android/compressed-pointer snapshot is incompatible with the supplied Linux/non-compressed-pointer Dart runner. That is **not** counted as a passing runtime test.
- No development HTTP server was started; this is a native Flutter app, not a web preview.

## Next verification in a full SDK environment

```sh
flutter pub get
flutter analyze
flutter test
node --test tool/project.test.mjs
flutter run --dart-define-from-file=config/monetization.example.json
```

Then complete the physical-device/sandbox matrix in [RELEASE.md](RELEASE.md), including:

1. Swipes 1–19, swipe 20 in either direction, next swipe after dismissing the paywall.
2. Choose ads, restart, swipe 10 more, ad-break cancel/continue, no-fill/offline.
3. No quota refunds from undo; keep-undo persists; double taps cannot overlap swipes.
4. Real monthly purchase; cancellation/pending; restore; expiry/refund; signed-response verification failure; no preloaded ad for Pro.
5. UMP initial form, refusal/change, privacy entry point, delayed user response, no IDFA prompt.
6. Limited media access on both platforms; denied/revoked permissions; video background pause; empty or cloud-only libraries.
7. Review/undo before deletion, confirmation cancellation, partial deletion, platform recovery wording.
8. Small phones/landscape, iPad/tablet, large text, safe-area and screen-reader review.

No claims of full Android/iOS experience parity or store readiness should be made from source compilation alone.
