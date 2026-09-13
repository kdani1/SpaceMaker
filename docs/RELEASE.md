# Android + iOS release checklist

## 1. What is and is not implemented

The shared Flutter UI and device gallery workflow are retained on both platforms. No own API deployment is required. RevenueCat is a managed receipt/entitlement service, **not an offline billing bypass**. AdMob is a managed ad service. A provider outage must not erase a gallery or require someone to subscribe.

This repository has integration code, not provisioned developer accounts or published products. Neither monthly prices nor ads have been activated in a store from this environment. Do not advertise it as store-ready until the checks below pass.

## 2. Store subscriptions and RevenueCat

1. Register the app in Google Play Console and App Store Connect. Android package / iOS bundle identifier: `app.spacemaker.swipe`. If a previously published iOS app has another identifier, retain its registered identifier and update this project before release; do not create an accidental second app.
2. Apple: create auto-renewing `spacemaker_pro_monthly`, period one month, in a Pro subscription group. Google: subscription `spacemaker_pro`, auto-renewing base plan `monthly`, period P1M. No introductory offer is assumed by this UI.
3. Set territories and local prices from `config/regional-pricing.json`, rounding to each console's supported price points. Other supported, approved markets start from the stores' localized equivalent of US $3.99. This JSON is a review plan, not a store-API payload or runtime price list.
4. In your RevenueCat account connect both store apps, import the products, attach both to entitlement **`pro`**, and add the appropriate product to the **monthly package** (`$rc_monthly`) of the current/default offering. Do not attach weekly/yearly or consumable products. Monthly UI refuses products whose store period is not P1M.
5. Complete store credentials/server notifications **in provider dashboards**, not in this repo/chat. RevenueCat's public platform SDK keys go in the build config (`goog_…`, `appl_…`); never include store private keys, service-account JSON or secret RevenueCat API keys in the app.
6. Anonymous RevenueCat identities avoid custom login. Restore uses the same store account on the same platform. There is no Android ↔ iOS subscription portability without adding a shared authenticated identity. Local trial usage can reset on reinstall/cleared data; this is not fraud-proof server accounting.
7. Verify sandbox purchase, pending purchase, cancel, renewal, billing grace, expiry, refund/revocation, restore after reinstall and store-offline behavior. SDK cached active access is accepted only while its expiration permits it; the app does not persist its own paid flag. Network errors do not fabricate a Pro purchase.

Official implementation references: [RevenueCat Flutter](https://www.revenuecat.com/docs/getting-started/installation/flutter), [customer info](https://www.revenuecat.com/docs/customers/customer-info), [restore](https://www.revenuecat.com/docs/getting-started/restoring-purchases).

## 3. AdMob and privacy

1. Create separate Android and iOS AdMob apps and interstitial units. Replace Google's **sample app IDs** in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. App IDs have `~`; ad unit IDs have `/` and go in build config. These are not interchangeable.
2. Configure and publish appropriate regional messages under AdMob Privacy & messaging. UMP refresh runs when an ad-supported session starts; no ad request is made until `canRequestAds()` allows it. The Settings privacy-options entry appears when UMP requires it. Choosing “Continue with ads” is not treated as consent.
3. Debug builds use Google's sample test units. Release defaults to no ads unless production unit IDs are provided. Set `TEST_ADS=false` for production. Register physical test devices before testing production IDs; never click live ads as a test.
4. The current integration requests non-personalized ads and does not request IDFA/ATT authorization. This is not a blanket privacy-compliance guarantee; review SDK collection, your actual distribution/age audience, regional consent, App Privacy, Play Data safety and advertising declarations. Non-personalized ads can still process personal data. If tracking is later added, implement the required platform authorization separately.
5. SKAdNetwork entries were sourced from the official Google iOS quick-start on 2026-09-13. Review at release and when adding mediation. Do not enable unsupported territories blindly.
6. Test no-fill, offline, consent refusal/change, background/foreground, ad dismissal/show failure and Pro activation with a preloaded ad. Gallery marking/deletion must never be coupled to ad success.

References: [Flutter setup](https://developers.google.com/admob/flutter/quick-start), [UMP](https://developers.google.com/admob/flutter/privacy), [test ads](https://developers.google.com/admob/flutter/test-ads), [iOS setup](https://developers.google.com/admob/ios/quick-start).

## 4. Public legal pages and build configuration

Publish accurate privacy policy and terms with publisher identity/contact, actual SDK data handling, retention and subscription details. No made-up publisher URLs are embedded. Until both HTTPS URLs are configured the subscribe button remains disabled. This is a release safety check, not a substitute for policy review.

Copy `config/monetization.example.json` to ignored `config/monetization.json` and fill **public configuration only**. Update the native AdMob app IDs separately.

```sh
flutter pub get
flutter analyze
flutter test
node tool/check_release.mjs config/monetization.json
flutter build appbundle --release --dart-define-from-file=config/monetization.json
# On macOS with Xcode, your signing team and provisioning configured:
flutter build ipa --release --dart-define-from-file=config/monetization.json
```

Android release currently uses the inherited **debug signing configuration**. Replace with your own release/upload key locally; do not commit signing material. Enable App Store In-App Purchase capability and configure the Apple team/provisioning before archiving. A full Flutter installation supplies generated plugin registration/build scaffolding. Review dependency resolution and native build errors; do not delete the billing/ads/gallery plugins to force a green build.

## 5. Same experience, platform-specific verification

- Shared UI, swipe direction, quota, undo, review bin, paywall and ad frequency.
- Selected/limited gallery access is accepted rather than requiring full-library permission.
- Native system dialogs, store checkout, refund handling and deletion/recovery differ by platform.
- Test Android 24+, current Android with selected media permissions, and iOS 15+ (also check the resolved plugin minimum OS/Xcode requirements). Device support is only confirmed after native compilation/testing.
- Test compact phones, iPad/tablets, landscape, safe areas and large text. English UI remains; add translations before claiming full linguistic localization.
- Confirm permissions denied/revoked/limited, huge galleries, cloud-only media, video decoding, delete cancellation, partial deletion and persistent undo.
- Default gallery marking is local preferences, not an online account. Deletion always requires user confirmation. Do not promise a universal 30-day recovery window.

## 6. Local build blocker (2026-09-13)

The Android client's `android_build_apk` resolved Pub packages, then refused:

```
Build failed: java.io.IOException: google_mobile_ads: Android dependency is not in the native SDK: com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.3.1. Add a compatible SDK library before building this plugin.
```

The builder does not execute full Gradle/Maven dependency resolution. No dependencies were removed or replaced because of this failure. Use a supported full build environment (or an updated native SDK from the Android client's maintainer). Further native plugin errors may surface there; a successful Dart compilation alone does not prove APK/IPA success.
