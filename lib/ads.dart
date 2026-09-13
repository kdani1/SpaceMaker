import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/monetization_config.dart';

class Ads extends ChangeNotifier {
  Ads._() { Entitlement.instance.addListener(_entitlementChanged); }
  static final instance = Ads._();
  InterstitialAd? _ad;
  bool _loading = false;
  int _generation = 0;
  bool _initialized = false;
  bool _consentReady = false;
  bool privacyOptionsRequired = false;
  Future<void>? _starting;
  String? message;
  bool get enabled => MonetizationConfig.interstitialId.isNotEmpty;

  void _entitlementChanged() {
    if (Entitlement.instance.isPlus) {
      _generation++;
      _ad?.dispose();
      _ad = null;
    }
  }

  Future<void> start() {
    if (Entitlement.instance.isPlus || !Entitlement.instance.adsChosen) return Future.value();
    if (_consentReady) return preload();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    if (!enabled) {
      message = 'Ads are not configured in this build. Free cleaning remains available.';
      notifyListeners();
      return;
    }
    if (Entitlement.instance.isPlus || !Entitlement.instance.adsChosen) return;
    final complete = Completer<void>();
    void done() { if (!complete.isCompleted) complete.complete(); }
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) message = 'Privacy options could not load. No ads will be requested without permission.';
          done();
        }),
        (error) { message = 'Privacy check unavailable. Cleaning is still available.'; done(); },
      );
      // Never time out a user reading a privacy form. This work is non-blocking.
      await complete.future;
      _consentReady = true;
      await _updatePrivacy();
      await preload();
    } catch (_) {
      message = 'Ads are unavailable right now. You can keep cleaning.';
    }
    notifyListeners();
  }

  Future<void> _updatePrivacy() async {
    privacyOptionsRequired = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    notifyListeners();
  }

  Future<void> privacyOptions() async {
    final complete = Completer<void>();
    _generation++;
    _ad?.dispose();
    _ad = null;
    ConsentForm.showPrivacyOptionsForm((error) {
      message = error == null ? 'Privacy choices updated.' : 'Privacy options could not open. Please retry.';
      if (!complete.isCompleted) complete.complete();
    });
    await complete.future;
    await _updatePrivacy();
    await preload();
  }

  Future<void> preload() async {
    if (!_consentReady || !enabled || _loading || _ad != null || Entitlement.instance.isPlus || !Entitlement.instance.adsChosen) return;
    _loading = true;
    final generation = _generation;
    try {
      if (!await ConsentInformation.instance.canRequestAds()) { _loading = false; return; }
      if (!_initialized) {
        await MobileAds.instance.initialize();
        _initialized = true;
      }
      await InterstitialAd.load(
        adUnitId: MonetizationConfig.interstitialId,
        // No IDFA prompt or personalized ad request in this version.
        request: const AdRequest(nonPersonalizedAds: true),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            if (Entitlement.instance.isPlus || generation != _generation) { ad.dispose(); return; }
            _ad = ad;
          },
          onAdFailedToLoad: (_) { _loading = false; message = 'No ad available. Continue cleaning.'; },
        ),
      );
    } catch (_) {
      _loading = false;
      message = 'Ads unavailable. Continue cleaning.';
    }
  }

  /// Only called from the explicit continue button at a batch break.
  /// No-fill/offline/consent denial never traps someone behind the paywall.
  Future<void> showAtBreak() async {
    if (Entitlement.instance.isPlus) return;
    final ad = _ad;
    _ad = null;
    if (ad == null) { unawaited(preload()); return; }
    try {
      if (!await ConsentInformation.instance.canRequestAds()) { ad.dispose(); return; }
    } catch (_) { ad.dispose(); return; }
    final complete = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) { ad.dispose(); if (!complete.isCompleted) complete.complete(); },
      onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); if (!complete.isCompleted) complete.complete(); },
    );
    try {
      await ad.show();
      await complete.future;
    } catch (_) {
      ad.dispose();
    }
    unawaited(preload());
  }
}
