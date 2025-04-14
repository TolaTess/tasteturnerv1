import '../constants.dart';

class Payment {
  final String id;
  final String userId;
  final String subscriptionId;
  final double amount;
  final String currency;
  final String status;
  final String? imageUrl;
  final Map<String, dynamic>? details;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.userId,
    required this.subscriptionId,
    required this.amount,
    required this.currency,
    required this.status,
    this.imageUrl = intPlaceholderImage,
    this.details,
    required this.createdAt,
    required this.updatedAt,
  });

  // ... existing code ...
}

// ... existing code ...

List<Payment> demoPayments = [
  Payment(
    id: '1',
    userId: '1',
    subscriptionId: '1',
    amount: 9.99,
    currency: 'USD',
    status: 'completed',
    imageUrl: intPlaceholderImage,
    details: {
      'paymentMethod': 'credit_card',
      'cardLast4': '4242',
      'transactionId': 'txn_123456',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Payment(
    id: '2',
    userId: '2',
    subscriptionId: '2',
    amount: 4.99,
    currency: 'USD',
    status: 'completed',
      imageUrl: intPlaceholderImage,
    details: {
      'paymentMethod': 'paypal',
      'transactionId': 'txn_789012',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];
