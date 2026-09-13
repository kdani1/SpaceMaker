import 'package:shared_preferences/shared_preferences.dart';

/// Device-scoped trial and Plus flag. Survives logout and app restarts so
/// closing the app cannot reset the five free deletes.
class Entitlement {
  Entitlement._();
  static final Entitlement instance = Entitlement._();

  static const trialDeletes = 5;
  static const _usedKey = 'sm_device_trial_used_v1';
  static const _plusKey = 'sm_device_plus_v1';
  static const _planKey = 'sm_device_plan_v1';

  int used = 0;
  bool isPlus = false;
  String? plan;

  int get remaining => isPlus ? -1 : (trialDeletes - used).clamp(0, trialDeletes);
  bool get canDelete => isPlus || used < trialDeletes;
  bool get trialExhausted => !isPlus && used >= trialDeletes;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    used = prefs.getInt(_usedKey) ?? 0;
    isPlus = prefs.getBool(_plusKey) ?? false;
    plan = prefs.getString(_planKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usedKey, used);
    await prefs.setBool(_plusKey, isPlus);
    if (plan == null) {
      await prefs.remove(_planKey);
    } else {
      await prefs.setString(_planKey, plan!);
    }
  }

  /// Server Plus wins. A free server account never resets a spent device trial.
  Future<void> syncFromAccount({required bool accountPlus, String? accountPlan}) async {
    if (accountPlus && !isPlus) {
      isPlus = true;
      plan = accountPlan ?? plan ?? 'yearly';
      await _persist();
    }
  }

  Future<bool> consumeDelete() async {
    if (isPlus) return true;
    if (used >= trialDeletes) return false;
    used += 1;
    await _persist();
    return true;
  }

  Future<void> refundDelete() async {
    if (isPlus || used <= 0) return;
    used -= 1;
    await _persist();
  }

  Future<void> activate(String selected) async {
    isPlus = true;
    plan = selected;
    await _persist();
  }

  String get statusLabel {
    if (isPlus) {
      return switch (plan) {
        'weekly' => 'Plus · weekly',
        'monthly' => 'Plus · monthly',
        'yearly' => 'Plus · yearly',
        _ => 'Plus',
      };
    }
    if (remaining == 0) return 'Free trial used';
    if (remaining == 1) return '1 free delete left';
    return '$remaining free deletes left';
  }
}

class Plans {
  static const weekly = PlanOption(
    id: 'weekly',
    title: 'Weekly',
    price: '\$2.49',
    note: 'Dip in for a weekend clean-out',
    detail: 'Billed every week. Cancel anytime.',
  );
  static const monthly = PlanOption(
    id: 'monthly',
    title: 'Monthly',
    price: '\$5.99',
    note: 'A quiet habit',
    detail: 'Billed monthly. Cancel anytime.',
  );
  static const yearly = PlanOption(
    id: 'yearly',
    title: 'Yearly',
    price: '\$29.99',
    note: 'Most chosen · \$2.50 / month',
    detail: 'Two months free versus monthly.',
    featured: true,
  );

  static const all = [weekly, monthly, yearly];
}

class PlanOption {
  const PlanOption({
    required this.id,
    required this.title,
    required this.price,
    required this.note,
    required this.detail,
    this.featured = false,
  });

  final String id;
  final String title;
  final String price;
  final String note;
  final String detail;
  final bool featured;
}
