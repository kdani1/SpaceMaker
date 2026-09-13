import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local usage only. A paid entitlement is never read from preferences.
class Entitlement extends ChangeNotifier {
  Entitlement();
  static final instance = Entitlement();
  static const trialSwipes = 20;
  static const adInterval = 10;
  int used = 0;
  int swipesSinceAd = 0;
  bool adsChosen = false;
  bool _pro = false;
  DateTime? _expires;
  SharedPreferences? _prefs;

  bool get isPlus => _pro && (_expires == null || DateTime.now().isBefore(_expires!));
  int get remaining => (trialSwipes - used).clamp(0, trialSwipes);
  bool get trialExhausted => !isPlus && remaining == 0;
  bool get canSwipe => isPlus || remaining > 0 || adsChosen;
  bool get adDue => !isPlus && adsChosen && remaining == 0 && swipesSinceAd >= adInterval;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    used = (p.getInt('sm_swipes_v2') ?? 0).clamp(0, trialSwipes);
    swipesSinceAd = (p.getInt('sm_ad_swipes_v2') ?? 0).clamp(0, adInterval);
    adsChosen = p.getBool('sm_ads_chosen_v2') ?? false;
    _pro = false;
    _expires = null;
    // Never migrate the old fake/local Plus flag to paid access.
    for (final key in ['api_url', 'token', 'offline', 'sm_device_plus_v1', 'sm_device_plan_v1']) {
      await p.remove(key);
    }
    notifyListeners();
  }

  void applyVerifiedPro({required bool active, DateTime? expires}) {
    _pro = active;
    _expires = expires;
    notifyListeners();
  }

  Future<void> chooseAds() async {
    await _prefs!.setBool('sm_ads_chosen_v2', true);
    adsChosen = true;
    notifyListeners();
  }

  /// Both keep and trash count. Undo does not refund a swipe.
  Future<bool> recordSwipe() async {
    if (!canSwipe) return false;
    if (!isPlus) {
      if (remaining > 0) {
        await _prefs!.setInt('sm_swipes_v2', used + 1);
        used++;
      } else {
        final next = (swipesSinceAd + 1).clamp(0, adInterval);
        await _prefs!.setInt('sm_ad_swipes_v2', next);
        swipesSinceAd = next;
      }
    }
    notifyListeners();
    return true;
  }

  Future<void> finishAdBreak() async {
    await _prefs!.setInt('sm_ad_swipes_v2', 0);
    swipesSinceAd = 0;
    notifyListeners();
  }

  String get statusLabel => isPlus ? 'Pro · ad-free' : adsChosen && remaining == 0
      ? 'Free · with ads' : '$remaining free swipes left';
}
