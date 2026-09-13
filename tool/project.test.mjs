import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
const read = f => fs.readFileSync(f, 'utf8');
test('pricing proposal has 50 unique valid territory overrides and a default', () => {
  const p = JSON.parse(read('config/regional-pricing.json'));
  assert.equal(p.status, 'proposal_not_published');
  assert.equal(p.overrides.length, 50);
  assert.equal(new Set(p.overrides.map(r => r.territory)).size, 50);
  for(const r of p.overrides) { assert.match(r.territory, /^[A-Z]{2}$/); assert.match(r.currency,/^[A-Z]{3}$/); assert.ok(r.amount>0); }
  assert.equal(p.defaultForOtherSupportedMarkets.amount, 3.99);
  assert.equal(p.product.period, 'P1M');
});
test('custom backend and fake purchase entrypoints are removed', () => {
  for(const p of ['backend','host','start-backend.ps1','lib/api.dart','lib/screens/login_screen.dart']) assert.ok(!fs.existsSync(p));
  for(const p of ['lib/main.dart','lib/screens/home_screen.dart','lib/screens/settings_screen.dart','lib/screens/paywall_screen.dart']) assert.doesNotMatch(read(p), /Api\.instance|LoginScreen|setBaseUrl|Backend URL/);
  assert.doesNotMatch(read('lib/entitlement.dart'), /Future<void> activate|setBool\([^\n]*plus/i);
});
test('both native identifiers and AdMob application metadata exist', () => {
  assert.match(read('android/app/build.gradle.kts'), /applicationId = "app\.spacemaker\.swipe"/);
  assert.match(read('ios/Runner.xcodeproj/project.pbxproj'), /PRODUCT_BUNDLE_IDENTIFIER = app\.spacemaker\.swipe;/);
  assert.match(read('android/app/src/main/AndroidManifest.xml'), /com\.google\.android\.gms\.ads\.APPLICATION_ID/);
  assert.match(read('ios/Runner/Info.plist'), /GADApplicationIdentifier/);
  assert.match(read('ios/Runner/Info.plist'), /cstr6suwn9\.skadnetwork/);
});
test('every referenced iOS image exists with the declared pixel dimensions', () => {
  for(const set of ['AppIcon.appiconset','LaunchImage.imageset']) {
    const base='ios/Runner/Assets.xcassets/'+set+'/';
    for(const i of JSON.parse(read(base+'Contents.json')).images) {
      const data=fs.readFileSync(base+i.filename);
      const n=Math.round((i.size ? parseFloat(i.size) : 108)*parseFloat(i.scale));
      assert.equal(data.readUInt32BE(16), n); assert.equal(data.readUInt32BE(20), n);
      assert.equal(data[25], 2, 'RGB without an alpha channel');
    }
  }
});
test('unsafe example release is rejected, without echoing keys', () => {
  const result=spawnSync(process.execPath,['tool/check_release.mjs','config/monetization.example.json'],{encoding:'utf8'});
  assert.equal(result.status,1);
  assert.match(result.stderr,/TEST_ADS must be false/);
  assert.match(result.stderr,/debug signing/);
});
test('checkout uses real localized product price and a verified purchase result', () => {
  assert.match(read('lib/screens/paywall_screen.dart'), /storeProduct\.priceString/);
  assert.match(read('lib/subscriptions.dart'), /Purchases\.purchase\(PurchaseParams\.package/);
  assert.match(read('lib/subscriptions.dart'), /VerificationResult\.verified/);
  assert.match(read('lib/screens/paywall_screen.dart'), /Continue with ads/);
  assert.match(read('lib/screens/paywall_screen.dart'), /Restore purchases/);
});
