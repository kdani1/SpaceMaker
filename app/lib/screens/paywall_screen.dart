import 'package:flutter/material.dart';
import 'package:spacemaker/api.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.freedLabel, this.reason});

  final String? freedLabel;
  final String? reason;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String plan = Plans.yearly.id;
  bool busy = false;
  String? error;

  Future<void> _buy() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.instance.activate(plan);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = Plans.all.firstWhere((p) => p.id == plan);
    final freed = widget.freedLabel;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 28, showWordmark: true, compact: true),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        children: [
          const BrandMark(size: 72),
          const SizedBox(height: 22),
          Text(
            freed == null ? 'Keep the space you just found' : 'Empty $freed — then keep going',
            style: SM.display,
          ),
          const SizedBox(height: 10),
          Text(
            widget.reason ??
                'Five free swipes. Your gallery is larger than that. Plus unlocks unlimited cleaning on this phone.',
            style: SM.body,
          ),
          const SizedBox(height: 22),
          _benefit('Unlimited left-swipes', 'No more stopping mid-clean.'),
          _benefit('Safe deletes', 'Files go to system trash, not into the void.'),
          _benefit('Stays on this phone', 'Photos are never uploaded.'),
          const SizedBox(height: 22),
          for (final option in Plans.all) ...[
            _plan(option),
            const SizedBox(height: 10),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: SM.toss, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          GoldButton(
            label: busy ? 'Opening Plus…' : 'Continue with ${selected.title}',
            onTap: busy ? () {} : _buy,
            enabled: !busy,
          ),
          const SizedBox(height: 10),
          Text(
            selected.detail,
            textAlign: TextAlign.center,
            style: SM.caption,
          ),
          const SizedBox(height: 16),
          const Text(
            'Local test billing: no store charge yet. The five free deletes stay used on this device even if you close the app.',
            style: SM.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _benefit(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: const BoxDecoration(color: SM.muted, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: SM.cream, fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: SM.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plan(PlanOption option) {
    final selected = plan == option.id;
    return InkWell(
      onTap: () => setState(() => plan = option.id),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: SM.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? SM.muted : SM.line, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: SM.muted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(option.title, style: const TextStyle(color: SM.cream, fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      if (option.featured) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SM.muted.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('MOST CHOSEN', style: TextStyle(color: SM.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(option.note, style: SM.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(option.price, style: const TextStyle(color: SM.cream, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
