import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spacemaker/ads.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/monetization_config.dart';
import 'package:spacemaker/subscriptions.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';
import 'package:spacemaker/screens/settings_screen.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.freedLabel, this.reason});
  final String? freedLabel;
  final String? reason;
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool choosingAds = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }
  Future<void> _load() async {
    await Subscriptions.instance.initialize();
    await Subscriptions.instance.refresh();
  }

  Future<void> _ads() async {
    if (choosingAds || Subscriptions.instance.busy) return;
    setState(() => choosingAds = true);
    try {
      await Entitlement.instance.chooseAds();
      // Privacy is gathered independently of the paywall; this is NOT ad consent.
      unawaited(Ads.instance.start());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => choosingAds = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your choice. Please retry.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Subscriptions.instance,
    builder: (context, _) {
      final store = Subscriptions.instance;
      final price = store.monthly?.storeProduct.priceString;
      final busy = choosingAds || store.busy;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(title: const BrandMark(size: 28, showWordmark: true, compact: true)),
          body: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 32), children: [
            const Icon(Icons.auto_awesome, size: 64, color: SM.muted),
            const SizedBox(height: 24),
            Text('More space.\nYour choice.', style: SM.display),
            const SizedBox(height: 14),
            Text(widget.reason ?? 'Start with 20 free swipes. Then keep cleaning with ads, or go Pro for an uninterrupted experience.', style: SM.body),
            const SizedBox(height: 24),
            const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.block, color: SM.muted), title: Text('Pro · no ads'), subtitle: Text('Unlimited swipes, every month.')),
            const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.photo_library_outlined, color: SM.muted), title: Text('Your photos stay on your device'), subtitle: Text('Review and undo before confirming deletion.')),
            const SizedBox(height: 18),
            Text(price == null ? 'Monthly Pro · store price unavailable' : '$price / month', style: SM.title),
            const SizedBox(height: 14),
            GoldButton(
              label: busy ? 'Please wait…' : price == null ? 'Subscription unavailable' : 'Subscribe · $price / month',
              enabled: !busy && price != null && MonetizationConfig.legalConfigured && !Entitlement.instance.isPlus,
              onTap: () async {
                if (await store.purchase() && context.mounted) Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: busy ? null : _ads,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: const Text('Continue with ads')),
            const SizedBox(height: 12),
            const Text('Free with ads: a short ad break after each 10 further swipes. No card or subscription required. If no ad is available, cleaning continues.', style: SM.caption),
            const SizedBox(height: 16),
            const Text('Pro is a monthly auto-renewing subscription, not a free subscription trial. Payment is charged to your store account after confirmation. Cancel in your store subscription settings before renewal. Access remains until the paid period ends.', style: SM.caption),
            if (store.message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(store.message!, style: SM.body)),
            if (!MonetizationConfig.legalConfigured) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Preview build: purchase is disabled until publisher terms and privacy policy are configured.', style: SM.caption)),
            Wrap(alignment: WrapAlignment.center, children: [
              TextButton(onPressed: busy ? null : () async {
                if (await store.restore() && context.mounted) Navigator.pop(context, true);
              }, child: const Text('Restore purchases')),
              TextButton(onPressed: busy ? null : _load, child: const Text('Retry store')),
              TextButton(onPressed: MonetizationConfig.legalConfigured ? () => openExternal(context, MonetizationConfig.termsUrl) : null, child: const Text('Terms')),
              TextButton(onPressed: MonetizationConfig.legalConfigured ? () => openExternal(context, MonetizationConfig.privacyUrl) : null, child: const Text('Privacy')),
            ]),
          ]),
        ),
      );
    },
  );
}
