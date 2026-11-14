import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum SubscriptionTier {
  free('free'),
  monthly('com.doseflow.app.monthly'),
  annual('com.doseflow.app.annual'),
  lifetime('com.doseflow.app.lifetime');

  const SubscriptionTier(this.productId);
  final String productId;
  bool get isPaid => this != SubscriptionTier.free;
}

enum PurchaseStatus {
  idle,
  purchasing,
  verifying,
  restored,
  expired,
  failed,
}

@immutable
class ProductItem {
  const ProductItem({
    required this.tier,
    required this.productId,
    required this.titleZh,
    required this.titleEn,
    required this.priceUsdString,
    required this.priceTwdString,
    required this.hasFreeTrial,
    required this.trialDays,
    required this.isBestValue,
  });

  final SubscriptionTier tier;
  final String productId;
  final String titleZh;
  final String titleEn;
  final String priceUsdString;
  final String priceTwdString;
  final bool hasFreeTrial;
  final int trialDays;
  final bool isBestValue;
}

class DoseFlowProductCatalog {
  const DoseFlowProductCatalog._();

  static const ProductItem monthly = ProductItem(
    tier: SubscriptionTier.monthly,
    productId: 'com.doseflow.app.monthly',
    titleZh: '月費常規 (彈性付費)',
    titleEn: 'Monthly Subscription',
    priceUsdString: r'$6.99',
    priceTwdString: r'NT$ 150',
    hasFreeTrial: false,
    trialDays: 0,
    isBestValue: false,
  );

  static const ProductItem annual = ProductItem(
    tier: SubscriptionTier.annual,
    productId: 'com.doseflow.app.annual',
    titleZh: '年繳解鎖 (三日猶豫與首選大成)',
    titleEn: 'Annual (Ulysses Commitment)',
    priceUsdString: r'$39.99',
    priceTwdString: r'NT$ 990',
    hasFreeTrial: true,
    trialDays: 3,
    isBestValue: true,
  );

  static const ProductItem lifetime = ProductItem(
    tier: SubscriptionTier.lifetime,
    productId: 'com.doseflow.app.lifetime',
    titleZh: '終身尊絕金牌卡 (米爾格羅姆機制專用)',
    titleEn: 'Lifetime Platinum Reserve',
    priceUsdString: r'$119.99',
    priceTwdString: r'NT$ 3,990',
    hasFreeTrial: false,
    trialDays: 0,
    isBestValue: false,
  );

  static const List<ProductItem> all = <ProductItem>[
    monthly,
    annual,
    lifetime,
  ];

  static ProductItem getByTier(SubscriptionTier tier) {
    return all.firstWhere(
      (ProductItem p) => p.tier == tier,
      orElse: () => annual,
    );
  }
}

@immutable
class ProEntitlementInfo {
  const ProEntitlementInfo({
    required this.isProUnlocked,
    required this.tier,
    this.originalPurchaseDate,
    this.expirationDate,
    this.isInTrial = false,
    this.jwsReceiptToken,
  });

  final bool isProUnlocked;
  final SubscriptionTier tier;
  final DateTime? originalPurchaseDate;
  final DateTime? expirationDate;
  final bool isInTrial;
  final String? jwsReceiptToken;

  factory ProEntitlementInfo.free() {
    return const ProEntitlementInfo(
      isProUnlocked: false,
      tier: SubscriptionTier.free,
    );
  }

  bool get isActive {
    if (!isProUnlocked) return false;
    if (tier == SubscriptionTier.lifetime) return true;
    if (expirationDate == null) return false;
    return expirationDate!.isAfter(DateTime.now());
  }
}

class PurchaseService extends ChangeNotifier {
  PurchaseService._() {
    _currentEntitlement = ProEntitlementInfo.free();
  }

  static final PurchaseService instance = PurchaseService._();

  ProEntitlementInfo _currentEntitlement = ProEntitlementInfo.free();
  PurchaseStatus _status = PurchaseStatus.idle;
  String? _lastErrorMessage;
  final Map<String, String> _localizedPrices = <String, String>{};

  static const MethodChannel _storeKitChannel =
      MethodChannel('com.doseflow.app/storekit');

  ProEntitlementInfo get currentEntitlement => _currentEntitlement;
  PurchaseStatus get status => _status;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isProUnlocked => _currentEntitlement.isActive;

  String displayPriceFor(SubscriptionTier tier) {
    final String? storePrice = _localizedPrices[tier.productId];
    if (storePrice != null && storePrice.isNotEmpty) {
      return storePrice;
    }
    return DoseFlowProductCatalog.getByTier(tier).priceUsdString;
  }

  Future<void> refreshLocalizedPrices() async {
    if (_isTestSandbox) return;
    try {
      final Map<dynamic, dynamic>? raw =
          await _storeKitChannel.invokeMethod<Map<dynamic, dynamic>>(
        'fetchProducts',
        <String, dynamic>{
          'productIds': <String>[
            SubscriptionTier.monthly.productId,
            SubscriptionTier.annual.productId,
            SubscriptionTier.lifetime.productId,
          ],
        },
      );
      if (raw != null && raw.isNotEmpty) {
        raw.forEach((dynamic k, dynamic v) {
          if (k != null && v != null) {
            _localizedPrices[k.toString()] = v.toString();
          }
        });
        notifyListeners();
      }
    } catch (_) {}
  }

  static bool get _isTestSandbox {
    if (kIsWeb) return true;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return true;
    }
  }

  Future<bool> purchase(SubscriptionTier tier) async {
    if (tier == SubscriptionTier.free) return false;
    if (_status == PurchaseStatus.purchasing ||
        _status == PurchaseStatus.verifying) {
      return false;
    }

    _status = PurchaseStatus.purchasing;
    _lastErrorMessage = null;
    notifyListeners();

    String? verifiedToken;
    if (_isTestSandbox) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      verifiedToken = base64Encode(
        utf8.encode('{"productId":"${tier.productId}"}'),
      );
    } else {
      try {
        verifiedToken = await _storeKitChannel.invokeMethod<String>(
          'purchaseProduct',
          <String, dynamic>{'productId': tier.productId},
        );
      } on PlatformException catch (e) {
        _status = PurchaseStatus.failed;
        _lastErrorMessage = e.message ?? e.code;
        notifyListeners();
        return false;
      } catch (e) {
        _status = PurchaseStatus.failed;
        _lastErrorMessage = e.toString();
        notifyListeners();
        return false;
      }
    }

    if (verifiedToken == null || verifiedToken.isEmpty) {
      _status = PurchaseStatus.failed;
      _lastErrorMessage = 'Empty StoreKit transaction';
      notifyListeners();
      return false;
    }

    _status = PurchaseStatus.verifying;
    notifyListeners();

    final DateTime now = DateTime.now();
    DateTime? expireDate;
    bool isInTrial = false;

    switch (tier) {
      case SubscriptionTier.monthly:
        expireDate = now.add(const Duration(days: 30));
      case SubscriptionTier.annual:
        expireDate = now.add(const Duration(days: 368));
        isInTrial = true;
      case SubscriptionTier.lifetime:
        expireDate = null;
      case SubscriptionTier.free:
        break;
    }

    _currentEntitlement = ProEntitlementInfo(
      isProUnlocked: true,
      tier: tier,
      originalPurchaseDate: now,
      expirationDate: expireDate,
      isInTrial: isInTrial,
      jwsReceiptToken: verifiedToken,
    );

    _status = PurchaseStatus.idle;
    notifyListeners();
    return true;
  }

  Future<bool> restorePurchases() async {
    if (_status == PurchaseStatus.purchasing ||
        _status == PurchaseStatus.verifying) {
      return false;
    }

    _status = PurchaseStatus.purchasing;
    _lastErrorMessage = null;
    notifyListeners();

    if (_isTestSandbox) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_currentEntitlement.isProUnlocked && _currentEntitlement.isActive) {
        _status = PurchaseStatus.restored;
        notifyListeners();
        return true;
      }
      _status = PurchaseStatus.idle;
      notifyListeners();
      return false;
    }

    try {
      final List<dynamic>? activeIds =
          await _storeKitChannel.invokeMethod<List<dynamic>>(
        'restorePurchases',
      );
      final List<String> ids = (activeIds ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList();

      SubscriptionTier? restoredTier;
      if (ids.contains(SubscriptionTier.lifetime.productId)) {
        restoredTier = SubscriptionTier.lifetime;
      } else if (ids.contains(SubscriptionTier.annual.productId)) {
        restoredTier = SubscriptionTier.annual;
      } else if (ids.contains(SubscriptionTier.monthly.productId)) {
        restoredTier = SubscriptionTier.monthly;
      }

      if (restoredTier != null) {
        final DateTime now = DateTime.now();
        _currentEntitlement = ProEntitlementInfo(
          isProUnlocked: true,
          tier: restoredTier,
          originalPurchaseDate: now,
          expirationDate: restoredTier == SubscriptionTier.lifetime
              ? null
              : now.add(const Duration(days: 365)),
        );
        _status = PurchaseStatus.restored;
        notifyListeners();
        return true;
      }
    } on PlatformException catch (e) {
      _lastErrorMessage = e.message ?? e.code;
    } catch (e) {
      _lastErrorMessage = e.toString();
    }

    _status = PurchaseStatus.idle;
    notifyListeners();
    return false;
  }

  void toggleProForTesting() {
    if (_currentEntitlement.isProUnlocked) {
      _currentEntitlement = ProEntitlementInfo.free();
    } else {
      _currentEntitlement = ProEntitlementInfo(
        isProUnlocked: true,
        tier: SubscriptionTier.annual,
        originalPurchaseDate: DateTime.now(),
        expirationDate: DateTime.now().add(const Duration(days: 368)),
        isInTrial: true,
        jwsReceiptToken: base64Encode(
          utf8.encode('{"productId":"com.doseflow.app.annual"}'),
        ),
      );
    }
    notifyListeners();
  }
}

class ReceiptValidator {
  const ReceiptValidator._();

  static bool isValidBase64(String? input) {
    if (input == null || input.isEmpty) return false;
    final String clean = input.replaceAll('\r', '').replaceAll('\n', '').trim();
    if (clean.length % 4 != 0) return false;
    return RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(clean);
  }

  static bool verifyLocalReceipt(String? receiptHash) {
    if (!isValidBase64(receiptHash)) return false;
    try {
      final String decoded = utf8.decode(base64Decode(receiptHash!));
      final Map<String, dynamic> data =
          jsonDecode(decoded) as Map<String, dynamic>;
      final String? productId = data['productId'] as String?;
      if (productId == null || !productId.startsWith('com.doseflow.app')) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ProAccessGate {
  const ProAccessGate._();

  static const int freeSyringeCalcQuota = 3;

  static bool canViewPkCurve({required bool isProUnlocked}) => isProUnlocked;

  static bool canUseSyringeCalculator({
    required bool isProUnlocked,
    required int usageCount,
  }) =>
      isProUnlocked || (usageCount < freeSyringeCalcQuota);

  static bool canViewDoseColoredWeight({required bool isProUnlocked}) =>
      isProUnlocked;

  static bool canAccessWidgets({required bool isProUnlocked}) => isProUnlocked;

  static bool canExportDoctorSummary({required bool isProUnlocked}) =>
      isProUnlocked;
}
