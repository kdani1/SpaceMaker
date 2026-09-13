import fs from 'node:fs';
const file = process.argv[2];
if (!file) { console.error('Usage: node tool/check_release.mjs <monetization.json>'); process.exit(1); }
const c = JSON.parse(fs.readFileSync(file, 'utf8'));
const errors = [];
if (c.TEST_ADS !== false) errors.push('TEST_ADS must be false.');
for (const [key, prefix] of [['REVENUECAT_ANDROID_KEY','goog_'],['REVENUECAT_IOS_KEY','appl_']]) {
  if (!c[key]?.startsWith(prefix)) errors.push(`${key}: platform public SDK key missing.`);
}
for (const key of ['ADMOB_ANDROID_INTERSTITIAL_ID','ADMOB_IOS_INTERSTITIAL_ID']) {
  if (!/^ca-app-pub-\d+\/\d+$/.test(c[key] ?? '') || c[key]?.includes('3940256099942544')) errors.push(`${key}: real ad unit ID required.`);
}
for (const key of ['PRIVACY_POLICY_URL','TERMS_URL']) {
  try { const u = new URL(c[key]); if (u.protocol !== 'https:' || /example\./.test(u.hostname)) throw Error(); }
  catch { errors.push(`${key}: published HTTPS policy URL required.`); }
}
for (const file of ['android/app/src/main/AndroidManifest.xml', 'ios/Runner/Info.plist']) {
  const text = fs.readFileSync(file, 'utf8');
  if (text.includes('3940256099942544')) errors.push(`${file}: replace Google sample app ID.`);
}
const gradle = fs.readFileSync('android/app/build.gradle.kts', 'utf8');
if (gradle.includes('signingConfigs.getByName("debug")')) errors.push('Android release still uses debug signing. Configure your upload key locally.');
if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
console.log('Static configuration check passed. Store setup, sandbox testing, policy review and release signing still require verification.');
