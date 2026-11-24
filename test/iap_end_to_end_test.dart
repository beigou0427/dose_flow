import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_flow/core/purchase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel storeKitChannel =
      MethodChannel('com.doseflow.app/storekit');

  final List<MethodCall> recordedCalls = <MethodCall>[];
  Map<String, String> mockPrices = <String, String>{};
  List<String> mockEntitlements = <String>[];
  Object? Function(String productId)? mockPurchaseHandler;

  setUp(() {
    recordedCalls.clear();
    mockPrices = <String, String>{
      'com.doseflow.app.monthly': r'NT$ 150',
      'com.doseflow.app.annual': r'NT$ 990',
      'com.doseflow.app.lifetime': r'NT$ 2,490',
    };
    mockEntitlements = <String>[];
    mockPurchaseHandler = (String productId) => 'eyJhbGciOiJFUzI1NiJ9.mock_jws_$productId';

    PurchaseService.forceChannelForTesting = true;
    PurchaseService.instance.resetToFreeForTesting();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storeKitChannel, (MethodCall call) async {
      recordedCalls.add(call);
      switch (call.method) {
        case 'fetchProducts':
          return mockPrices;
        case 'checkEntitlements':
          return mockEntitlements;
        case 'restorePurchases':
          return mockEntitlements;
        case 'purchaseProduct':
          final Map<dynamic, dynamic> args =
              call.arguments as Map<dynamic, dynamic>;
          final String productId = args['productId'] as String;
          final Object? outcome = mockPurchaseHandler?.call(productId);
          if (outcome is PlatformException) throw outcome;
          return outcome;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    PurchaseService.forceChannelForTesting = false;
    PurchaseService.instance.resetToFreeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storeKitChannel, null);
  });

  group('StoreKit 2 MethodChannel End-to-End IAP Verification', () {
    test('Fresh install with no StoreKit entitlements remains locked (Free)', () async {
      mockEntitlements = <String>[];

      await PurchaseService.instance.syncCurrentEntitlements();

      expect(PurchaseService.instance.isProUnlocked, isFalse);
      expect(
        PurchaseService.instance.currentEntitlement.tier,
        equals(SubscriptionTier.free),
      );
      expect(
        recordedCalls.any((MethodCall c) => c.method == 'checkEntitlements'),
        isTrue,
      );
    });

    test('refreshLocalizedPrices fetches and displays StoreKit localized prices', () async {
      await PurchaseService.instance.refreshLocalizedPrices();

      expect(
        PurchaseService.instance.displayPriceFor(SubscriptionTier.monthly),
        equals(r'NT$ 150'),
      );
      expect(
        PurchaseService.instance.displayPriceFor(SubscriptionTier.annual),
        equals(r'NT$ 990'),
      );
      expect(
        PurchaseService.instance.displayPriceFor(SubscriptionTier.lifetime),
        equals(r'NT$ 2,490'),
      );
    });

    test('Cancelled StoreKit purchase keeps Pro strictly locked', () async {
      mockPurchaseHandler = (_) => PlatformException(
            code: 'USER_CANCELLED',
            message: 'Purchase cancelled by user',
          );

      final bool ok =
          await PurchaseService.instance.purchase(SubscriptionTier.annual);

      expect(ok, isFalse);
      expect(PurchaseService.instance.isProUnlocked, isFalse);
      expect(PurchaseService.instance.status, equals(PurchaseStatus.failed));
      expect(
        PurchaseService.instance.lastErrorMessage,
        equals('Purchase cancelled by user'),
      );
    });

    test('Empty JWS token or missing product keeps Pro strictly locked', () async {
      mockPurchaseHandler = (_) => '';
      final bool emptyOk =
          await PurchaseService.instance.purchase(SubscriptionTier.monthly);
      expect(emptyOk, isFalse);
      expect(PurchaseService.instance.isProUnlocked, isFalse);

      mockPurchaseHandler = (_) => PlatformException(
            code: 'PRODUCT_NOT_FOUND',
            message: 'Product unavailable',
          );
      final bool missingOk =
          await PurchaseService.instance.purchase(SubscriptionTier.lifetime);
      expect(missingOk, isFalse);
      expect(PurchaseService.instance.isProUnlocked, isFalse);
    });

    test('Verified StoreKit purchase unlocks corresponding Pro tier', () async {
      final bool ok =
          await PurchaseService.instance.purchase(SubscriptionTier.annual);

      expect(ok, isTrue);
      expect(PurchaseService.instance.isProUnlocked, isTrue);
      expect(
        PurchaseService.instance.currentEntitlement.tier,
        equals(SubscriptionTier.annual),
      );
      expect(PurchaseService.instance.currentEntitlement.isInTrial, isTrue);
      expect(
        PurchaseService.instance.currentEntitlement.jwsReceiptToken,
        contains('com.doseflow.app.annual'),
      );
    });

    test('Lifetime purchase unlocks permanently with null expirationDate', () async {
      final bool ok =
          await PurchaseService.instance.purchase(SubscriptionTier.lifetime);

      expect(ok, isTrue);
      expect(PurchaseService.instance.isProUnlocked, isTrue);
      expect(
        PurchaseService.instance.currentEntitlement.tier,
        equals(SubscriptionTier.lifetime),
      );
      expect(PurchaseService.instance.currentEntitlement.expirationDate, isNull);
    });

    test('Restore purchases returns false when user has no active entitlements', () async {
      mockEntitlements = <String>[];

      final bool restored = await PurchaseService.instance.restorePurchases();

      expect(restored, isFalse);
      expect(PurchaseService.instance.isProUnlocked, isFalse);
    });

    test('Restore purchases and startup sync unlock highest active tier', () async {
      mockEntitlements = <String>[
        'com.doseflow.app.monthly',
        'com.doseflow.app.lifetime',
      ];

      final bool restored = await PurchaseService.instance.restorePurchases();
      expect(restored, isTrue);
      expect(PurchaseService.instance.isProUnlocked, isTrue);
      expect(
        PurchaseService.instance.currentEntitlement.tier,
        equals(SubscriptionTier.lifetime),
      );

      // Reset and verify silent startup syncCurrentEntitlements restores entitlement
      PurchaseService.instance.resetToFreeForTesting();
      expect(PurchaseService.instance.isProUnlocked, isFalse);

      await PurchaseService.instance.syncCurrentEntitlements();
      expect(PurchaseService.instance.isProUnlocked, isTrue);
      expect(
        PurchaseService.instance.currentEntitlement.tier,
        equals(SubscriptionTier.lifetime),
      );
    });
  });
}
