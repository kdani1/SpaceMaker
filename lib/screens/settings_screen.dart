import 'dart:io';
import 'package:flutter/material.dart';
import 'package:spacemaker/ads.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/monetization_config.dart';
import 'package:spacemaker/subscriptions.dart';
import 'package:spacemaker/screens/paywall_screen.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternal(BuildContext context, String address) async {
  final uri = Uri.tryParse(address);
  try {
    if (uri == null || uri.scheme != 'https' || !await launchUrl(uri, mode: LaunchMode.externalApplication)) throw StateError('Unavailable');
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link. Please try again.')));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([Entitlement.instance, Subscriptions.instance, Ads.instance]),
    builder: (context, _) {
      final bill = Entitlement.instance;
      final store = Subscriptions.instance;
      return Scaffold(
        appBar: AppBar(title: const BrandMark(size: 28, showWordmark: true, compact: true)),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text('This device', style: SM.title),
          const SizedBox(height: 8),
          Text(bill.statusLabel, style: SM.body),
          const SizedBox(height: 20),
          if (!bill.isPlus) GoldButton(label: 'Pro · remove ads', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()))),
          TextButton(onPressed: store.busy ? null : () async { await store.restore(); }, child: const Text('Restore purchases')),
          TextButton(onPressed: () => openExternal(context, store.managementUrl ?? (Platform.isIOS
            ? 'https://apps.apple.com/account/subscriptions'
            : 'https://play.google.com/store/account/subscriptions')),
            child: const Text('Manage / cancel subscription')),
          if (store.message != null) Text(store.message!, style: SM.caption),
          const Divider(height: 32),
          const Text('No login. No server address.', style: SM.title),
          const SizedBox(height: 8),
          const Text('Photos and videos are processed on this device. Purchases use your app-store account and RevenueCat for validation. The ad-supported option uses Google AdMob. These services need internet, but your media is not uploaded to them.', style: SM.body),
          const SizedBox(height: 16),
          const Text('The 20-swipe allowance counts both directions and survives restarts. Undo does not refund swipes. Reinstalling or clearing app data may reset local usage. Purchases can be restored using the same platform store account; they do not transfer between Android and iOS in this account-free version.', style: SM.caption),
          const SizedBox(height: 16),
          const Text('Swiping only marks items for review. Emptying the bin asks for confirmation. Recovery and system trash behavior depend on your device and photo provider.', style: SM.caption),
          if (Ads.instance.privacyOptionsRequired) TextButton(onPressed: () async {
            try { await Ads.instance.privacyOptions(); } catch (_) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privacy options unavailable. Try again later.')));
            }
          }, child: const Text('Ad privacy choices')),
          if (Ads.instance.message != null) Text(Ads.instance.message!, style: SM.caption),
          TextButton(onPressed: MonetizationConfig.legalConfigured ? () => openExternal(context, MonetizationConfig.privacyUrl) : null, child: const Text('Privacy policy')),
          TextButton(onPressed: MonetizationConfig.legalConfigured ? () => openExternal(context, MonetizationConfig.termsUrl) : null, child: const Text('Terms of use')),
          if (MonetizationConfig.testAds) const Text('Development build · Google test ads only', style: SM.caption),
        ]),
      );
    },
  );
}
