import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacemaker/entitlement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Entitlement bill;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    bill = Entitlement();
    await bill.load();
  });
  tearDown(() => bill.dispose());

  test('exactly 20 swipes, then choice required', () async {
    for (var i = 0; i < 20; i++) { expect(await bill.recordSwipe(), isTrue); }
    expect(bill.remaining, 0);
    expect(bill.canSwipe, isFalse);
    expect(await bill.recordSwipe(), isFalse);
  });
  test('usage and ads choice survive a restart', () async {
    for (var i = 0; i < 20; i++) { await bill.recordSwipe(); }
    await bill.chooseAds();
    await bill.recordSwipe();
    await bill.load();
    expect(bill.remaining, 0);
    expect(bill.adsChosen, isTrue);
    expect(bill.swipesSinceAd, 1);
    expect(bill.canSwipe, isTrue);
  });
  test('ads only after 10 additional swipes', () async {
    await bill.chooseAds();
    for (var i = 0; i < 29; i++) { await bill.recordSwipe(); }
    expect(bill.adDue, isFalse);
    await bill.recordSwipe();
    expect(bill.adDue, isTrue);
    await bill.finishAdBreak();
    expect(bill.adDue, isFalse);
    expect(bill.swipesSinceAd, 0);
  });
  test('verified Pro does not consume quota or show ads', () async {
    bill.applyVerifiedPro(active: true, expires: DateTime.now().add(const Duration(days: 30)));
    for (var i = 0; i < 100; i++) { expect(await bill.recordSwipe(), isTrue); }
    expect(bill.remaining, 20);
    expect(bill.adDue, isFalse);
    expect(bill.statusLabel, 'Pro · ad-free');
  });
  test('expiry and revocation remove Pro without resetting usage', () async {
    for (var i = 0; i < 20; i++) { await bill.recordSwipe(); }
    bill.applyVerifiedPro(active: true, expires: DateTime.now().subtract(const Duration(seconds: 1)));
    expect(bill.isPlus, isFalse);
    expect(bill.canSwipe, isFalse);
    bill.applyVerifiedPro(active: true, expires: DateTime.now().add(const Duration(days: 1)));
    bill.applyVerifiedPro(active: false);
    expect(bill.canSwipe, isFalse);
  });
  test('old test Plus and stored login do not unlock a subscription', () async {
    SharedPreferences.setMockInitialValues({'sm_device_plus_v1': true, 'token': 'old-test-token', 'api_url': 'http://old.local'});
    await bill.load();
    expect(bill.isPlus, isFalse);
    final p = await SharedPreferences.getInstance();
    expect(p.containsKey('token'), isFalse);
    expect(p.containsKey('api_url'), isFalse);
  });
  test('negative or excessive counters are clamped', () async {
    SharedPreferences.setMockInitialValues({'sm_swipes_v2': -1, 'sm_ad_swipes_v2': 999});
    await bill.load();
    expect(bill.remaining, 20);
    expect(bill.swipesSinceAd, 10);
  });
}
