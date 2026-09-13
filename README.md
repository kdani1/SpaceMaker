# SpaceMaker

A device-first Flutter photo/video cleaner for Android and iOS. No custom backend, login, password, server address, APK host, or local fake purchase activation.

## Cleaning and monetization

- First **20 swipes** are free and ad-free. Both directions count; undo does not refund usage.
- Then choose **monthly Pro** (unlimited, no ads) or **Continue with ads** (free, no card).
- Ad-supported cleaning has an explicit break between each further batch of 10 swipes. Offline/no-fill does not block cleaning. Privacy choices are separate from choosing the free plan.
- Google AdMob + UMP privacy flow; test ad IDs in development, no production IDs embedded.
- RevenueCat validates App Store / Google Play purchases; signed entitlement response checked, restore supported, expiry/revocation handled. No locally stored paid flag.
- Localized monthly prices come from the store, not from phone language or hardcoded estimates.
- Media stays on-device. Purchases and ads contact their managed services; this is **not** a promise of zero network traffic.
- Mark for trash, review, undo, then explicitly confirm deletion. Recovery depends on platform/provider.

The Flutter project is now at repository root (previously `app/`) so the on-phone builder can detect `pubspec.yaml`. The obsolete `backend/`, `host/` and Windows server launcher were removed.

## Current verification

Pub dependency resolution succeeded. The on-phone APK build is **blocked** by its native SDK, not replaced with mock ads:

```
google_mobile_ads: Android dependency is not in the native SDK:
com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.3.1
```

No new APK or iOS archive has been produced. Use a full Flutter + Android SDK / macOS Xcode environment for native builds. See [verification](docs/VERIFICATION.md) for the final source-check results and unrun device tests.

## Run / publish

See [release checklist](docs/RELEASE.md). Configure your own store products, RevenueCat project, AdMob apps, published legal pages and signing before selling anything. Without configuration the app does not fake a purchase or a store price; free cleaning remains available.

- [Havi árterv magyarul – 50 piac + további támogatott piacok](docs/ARAZAS.md)
- [Machine-readable pricing proposal](config/regional-pricing.json)
- [Example build configuration](config/monetization.example.json)

In a full Flutter environment:

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/monetization.example.json
```

Runtime interface remains English, matching the previous app. Prices are localized by the store. Additional UI translations and actual Android/iOS usability checks remain release work.
