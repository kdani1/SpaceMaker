import 'dart:io';
import 'package:flutter/foundation.dart';

class MonetizationConfig {
  static const entitlement = 'pro';
  static const testAds = bool.fromEnvironment('TEST_ADS', defaultValue: !kReleaseMode);
  static String get revenueCatKey => Platform.isIOS
      ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
      : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static String get interstitialId => testAds
      ? (Platform.isIOS ? 'ca-app-pub-3940256099942544/4411468910' : 'ca-app-pub-3940256099942544/1033173712')
      : (Platform.isIOS ? const String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID') : const String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL_ID'));
  static const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static bool get legalConfigured => [privacyUrl, termsUrl].every((value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  });
}
