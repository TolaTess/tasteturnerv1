import 'package:in_app_purchase/in_app_purchase.dart';
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
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      _purchaseResultController.addError('In-app purchases are not available.');
      return;
    }
    _subscription =
        _inAppPurchase.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      _purchaseResultController.addError(error);
    });
    final ids = <String>{monthlyId, yearlyId};
    final response = await _inAppPurchase.queryProductDetails(ids);
    if (response.error != null) {
      _purchaseResultController.addError(response.error!.message);
    } else {
      _products = response.productDetails.toList();
    }
    _initialized = true;
  }

  Future<void> buyMonthly() async {
    await initialize();
    final product = _products.firstWhere((p) => p.id == monthlyId,
        orElse: () => throw Exception('Monthly product not found'));
    final purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> buyYearly() async {
    await initialize();
    final product = _products.firstWhere((p) => p.id == yearlyId,
        orElse: () => throw Exception('Yearly product not found'));
    final purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      _purchaseResultController.add(purchaseDetails);
      if (purchaseDetails.pendingCompletePurchase) {
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
