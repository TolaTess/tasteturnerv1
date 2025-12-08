import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'dart:async';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<PurchaseDetails?> _purchaseResultController =
      StreamController.broadcast();
  List<ProductDetails> _products = [];
  bool _initialized = false;

  static const String monthlyId = 'premium_monthly';
  static const String yearlyId = 'premium_yearly';

  Future<void> initialize() async {
    if (_initialized) return;

    print('🔧 Initializing PaymentService...');

    // Register StoreKit platform for iOS (important for subscriptions)
    if (Platform.isIOS) {
      try {
        InAppPurchaseStoreKitPlatform.registerPlatform();
        print('📱 Platform is iOS - StoreKit platform registered');
      } catch (e) {
        print('⚠️ StoreKit registration error: $e');
        // Continue anyway - main package should still work
      }
    }

    print('🆔 Product IDs to query: $monthlyId, $yearlyId');
    print('📋 Expected Bundle ID: com.tasteturner.fitHify');
    print('⚠️ IMPORTANT: If 0 products found, verify:');
    print('   1. Bundle ID in Xcode = com.tasteturner.fitHify');
    print('   2. Bundle ID in App Store Connect = com.tasteturner.fitHify');
    print('   3. Products are under THIS app (not another app)');
    print('   4. Products are in a subscription group together');
    print('   5. Waited 24-48 hours after creating products');

    final available = await _inAppPurchase.isAvailable();
    print('📡 In-App Purchase available: $available');

    if (!available) {
      final errorMsg =
          'In-app purchases are not available. Please ensure you are testing on a real device (subscriptions do not work on iOS Simulator).';
      print('❌ $errorMsg');
      _purchaseResultController.addError(errorMsg);
      return;
    }

    _subscription =
        _inAppPurchase.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      print('❌ Purchase stream error: $error');
      _purchaseResultController.addError(error);
    });

    final ids = <String>{monthlyId, yearlyId};
    print('🔍 Querying products with IDs: $ids');
    print('⏳ Waiting for StoreKit response...');

    try {
      final response = await _inAppPurchase.queryProductDetails(ids);

      if (response.error != null) {
        final errorMsg = response.error!.message;
        final errorCode = response.error!.code;
        print('❌ Error querying products:');
        print('   Message: $errorMsg');
        print('   Code: $errorCode');
        print('   Details: ${response.error}');

        // Provide helpful error messages for common issues
        if (errorMsg.contains('Failed to get response from platform') ||
            errorMsg.contains('StoreKit')) {
          final detailedError = '''$errorMsg

Troubleshooting Steps:
1. ✅ Verify you're on a REAL DEVICE (not Simulator)
2. ✅ Check products exist in App Store Connect → Subscriptions
3. ✅ Verify product status is "Ready to Submit" or "Approved" (not "Rejected" or "Developer Action Needed")
4. ✅ Ensure bundle ID matches App Store Connect exactly
5. ✅ Check product IDs match exactly: premium_monthly, premium_yearly (case-sensitive)
6. ✅ Sign out of regular Apple ID on device (Settings → App Store)
7. ✅ Wait 15-30 minutes if products were just created/updated
8. ✅ Check internet connection
9. ⚠️  This is a CLIENT-SIDE StoreKit error - server is NOT involved yet

Note: Server only runs AFTER successful purchase to verify receipt.''';
          _purchaseResultController.addError(detailedError);
        } else {
          _purchaseResultController.addError(errorMsg);
        }
      } else {
        _products = response.productDetails.toList();
        print('✅ Query successful!');
        print('📦 Found ${_products.length} products:');
        for (var product in _products) {
          print('   - ${product.id}: ${product.title} (${product.price})');
        }
        if (_products.isEmpty) {
          print(
              '⚠️ Warning: No products found. Verify product IDs match App Store Connect exactly.');
          print('   Expected: $monthlyId, $yearlyId');
        }
      }
    } catch (e) {
      print('❌ Exception during product query: $e');
      _purchaseResultController.addError('Failed to query products: $e');
    }

    _initialized = true;
    print('✅ PaymentService initialized');
  }

  Future<void> buyMonthly({String? userId}) async {
    await initialize();
    final product = _products.firstWhere((p) => p.id == monthlyId,
        orElse: () => throw Exception('Monthly product not found'));
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName:
          userId, // This becomes appAccountToken in server notifications
    );
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> buyYearly({String? userId}) async {
    await initialize();
    final product = _products.firstWhere((p) => p.id == yearlyId,
        orElse: () => throw Exception('Yearly product not found'));
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName:
          userId, // This becomes appAccountToken in server notifications
    );
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      print(
          '📦 Purchase update: ${purchaseDetails.productID} - Status: ${purchaseDetails.status}');

      // Access iOS-specific transaction details if available
      if (Platform.isIOS && purchaseDetails is AppStorePurchaseDetails) {
        final transactionId =
            purchaseDetails.skPaymentTransaction.transactionIdentifier;
        print('🧾 iOS Transaction ID: $transactionId');
      }

      _purchaseResultController.add(purchaseDetails);
      if (purchaseDetails.pendingCompletePurchase) {
        print(
            '✅ Completing pending purchase for: ${purchaseDetails.productID}');
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Stream<PurchaseDetails?> get purchaseResults =>
      _purchaseResultController.stream;

  void dispose() {
    _subscription?.cancel();
    _purchaseResultController.close();
    _initialized = false;
  }
}
