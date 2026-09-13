import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/monetization_config.dart';

/// Managed receipt validation: no custom backend and no local purchase bypass.
class Subscriptions extends ChangeNotifier {
  Subscriptions._();
  static final instance = Subscriptions._();
  bool _configured = false;
  Future<void>? _initializing;
  bool busy = false;
  Package? monthly;
  String? message;
  String? managementUrl;
  Timer? _expiryTimer;
  DateTime? _lastRequestDate;
  bool _verificationFailed = false;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (MonetizationConfig.revenueCatKey.isEmpty) {
      message = 'Subscriptions are not configured in this build. You can continue with ads.';
      notifyListeners();
      return;
    }
    try {
      final configuration = PurchasesConfiguration(MonetizationConfig.revenueCatKey)
        ..entitlementVerificationMode = EntitlementVerificationMode.informational;
      await Purchases.configure(configuration);
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      await refresh();
    } catch (_) {
      message = 'The store is unavailable. Continue free or try again later.';
      _initializing = null;
      notifyListeners();
    }
  }

  void _apply(CustomerInfo info) {
    final requestDate = DateTime.tryParse(info.requestDate);
    if (requestDate != null && _lastRequestDate != null && requestDate.isBefore(_lastRequestDate!)) return;
    final verification = info.entitlements.verification;
    if (verification != VerificationResult.verified && verification != VerificationResult.verifiedOnDevice) {
      _verificationFailed = true;
      _expiryTimer?.cancel();
      Entitlement.instance.applyVerifiedPro(active: false);
      message = 'Could not verify subscription securely. Please restore or retry.';
      notifyListeners();
      return;
    }
    _verificationFailed = false;
    if (requestDate != null) _lastRequestDate = requestDate;
    final pro = info.entitlements.active[MonetizationConfig.entitlement];
    final expires = pro?.expirationDate == null ? null : DateTime.tryParse(pro!.expirationDate!);
    Entitlement.instance.applyVerifiedPro(active: pro?.isActive == true && expires != null, expires: expires);
    managementUrl = info.managementURL;
    _expiryTimer?.cancel();
    if (expires != null && expires.isAfter(DateTime.now())) {
      _expiryTimer = Timer(expires.difference(DateTime.now()) + const Duration(seconds: 1), () {
        Entitlement.instance.applyVerifiedPro(active: false);
        unawaited(refresh());
      });
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!_configured) return;
    try {
      _apply(await Purchases.getCustomerInfo());
      monthly = (await Purchases.getOfferings()).current?.monthly;
      // Reject misconfigured weekly/yearly packages.
      if (monthly?.storeProduct.subscriptionPeriod != 'P1M') monthly = null;
      if (!_verificationFailed) message = monthly == null ? 'Monthly Pro is unavailable in this store. Continue with ads or retry.' : null;
    } catch (_) {
      message = 'Could not refresh the store. Check your connection and retry.';
    }
    notifyListeners();
  }

  Future<bool> purchase() async {
    if (busy || monthly == null || !MonetizationConfig.legalConfigured) return false;
    busy = true;
    message = null;
    notifyListeners();
    try {
      final result = await Purchases.purchase(PurchaseParams.package(monthly!));
      _apply(result.customerInfo);
      if (!Entitlement.instance.isPlus && !_verificationFailed) message = 'Purchase pending approval. Pro unlocks after store confirmation.';
      return Entitlement.instance.isPlus;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      message = code == PurchasesErrorCode.purchaseCancelledError
          ? 'Purchase cancelled. Nothing was unlocked.'
          : 'Purchase not confirmed. You can continue with ads or restore later.';
      return false;
    } catch (_) {
      message = 'Purchase could not be confirmed. Try restoring purchases.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> restore() async {
    if (busy) return false;
    await initialize();
    if (!_configured || busy) return false;
    busy = true;
    notifyListeners();
    try {
      _apply(await Purchases.restorePurchases());
      if (!_verificationFailed) message = Entitlement.instance.isPlus ? 'Pro restored.' : 'No active Pro subscription found for this store account.';
      return Entitlement.instance.isPlus;
    } catch (_) {
      message = 'Restore failed. Check your store account and connection.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
