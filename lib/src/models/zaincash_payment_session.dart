import 'zaincash_transaction_details.dart';

/// Result of creating a payment
/// (`POST /api/v2/payment-gateway/transaction/init`).
///
/// Redirect the customer to [redirectUrl] to complete the payment. Per the
/// ZainCash docs, always use the returned URL as-is; never construct it
/// manually.
class ZainCashPaymentSession {
  const ZainCashPaymentSession({
    required this.status,
    required this.transactionId,
    required this.redirectUrl,
    this.externalReferenceId,
    this.orderId,
    this.amount,
    this.currency,
    this.expiryTime,
    this.createdAt,
    this.raw = const {},
  });

  /// Init status reported by ZainCash (`SUCCESS` when created).
  final ZainCashTransactionStatus status;

  /// The ZainCash transaction id (UUID). Save it for inquiry/reversal.
  final String transactionId;

  /// The hosted payment page URL the customer must be redirected to.
  final String redirectUrl;

  /// Your `externalReferenceId` echoed back.
  final String? externalReferenceId;

  /// Your order id echoed back.
  final String? orderId;

  /// Transaction amount.
  final num? amount;

  /// Currency, always `IQD`.
  final String? currency;

  /// When the payment session expires.
  final DateTime? expiryTime;

  /// When the transaction was created.
  final DateTime? createdAt;

  /// The full decoded response payload.
  final Map<String, dynamic> raw;

  /// Builds a session from a decoded init response [json].
  factory ZainCashPaymentSession.fromJson(Map<String, dynamic> json) {
    final details =
        (json['transactionDetails'] as Map?)?.cast<String, dynamic>() ?? {};
    final amount = (details['amount'] as Map?)?.cast<String, dynamic>() ?? {};

    return ZainCashPaymentSession(
      status: ZainCashTransactionStatus.fromString(json['status']?.toString()),
      transactionId: details['transactionId']?.toString() ?? '',
      redirectUrl: json['redirectUrl']?.toString() ?? '',
      externalReferenceId: details['externalReferenceId']?.toString(),
      orderId: details['orderId']?.toString(),
      amount: num.tryParse(amount['value']?.toString() ?? ''),
      currency: amount['currency']?.toString(),
      expiryTime: DateTime.tryParse(json['expiryTime']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      raw: json,
    );
  }

  @override
  String toString() =>
      'ZainCashPaymentSession(transactionId: $transactionId, '
      'status: $status, redirectUrl: $redirectUrl)';
}
