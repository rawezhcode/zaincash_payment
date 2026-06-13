/// Lifecycle status of a ZainCash Payment Gateway v2 transaction.
enum ZainCashTransactionStatus {
  /// Final state - payment completed successfully.
  success,

  /// Final state - payment attempt failed.
  failed,

  /// Transaction created; awaiting next steps.
  pending,

  /// OTP delivered to the customer for authentication.
  otpSent,

  /// Extra steps required (e.g. phone validation, fee computation).
  customerAuthenticationRequired,

  /// Transaction exceeded its expiry time.
  expired,

  /// Final state - successful reversal/refund completed.
  refunded,

  /// Any unrecognized status.
  unknown;

  /// Maps a raw status string (e.g. `OTP_SENT`) to a status value.
  static ZainCashTransactionStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'SUCCESS':
        return ZainCashTransactionStatus.success;
      case 'FAILED':
        return ZainCashTransactionStatus.failed;
      case 'PENDING':
        return ZainCashTransactionStatus.pending;
      case 'OTP_SENT':
        return ZainCashTransactionStatus.otpSent;
      case 'CUSTOMER_AUTHENTICATION_REQUIRED':
        return ZainCashTransactionStatus.customerAuthenticationRequired;
      case 'EXPIRED':
        return ZainCashTransactionStatus.expired;
      case 'REFUNDED':
        return ZainCashTransactionStatus.refunded;
      default:
        return ZainCashTransactionStatus.unknown;
    }
  }
}

/// Transaction details returned by the inquiry endpoint
/// (`GET /api/v2/payment-gateway/transaction/inquiry/{transactionId}`).
class ZainCashTransactionDetails {
  const ZainCashTransactionDetails({
    required this.status,
    required this.transactionId,
    this.operationId,
    this.externalReferenceId,
    this.orderId,
    this.amount,
    this.feeValue,
    this.currency,
    this.customerPhone,
    this.expiryTime,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.raw = const {},
  });

  /// Current lifecycle status of the transaction.
  final ZainCashTransactionStatus status;

  /// The ZainCash transaction id (UUID).
  final String transactionId;

  /// ZainCash operation id, available once processed.
  final String? operationId;

  /// Your `externalReferenceId` echoed back.
  final String? externalReferenceId;

  /// Your order id echoed back.
  final String? orderId;

  /// Transaction amount.
  final num? amount;

  /// Fee charged for the transaction.
  final num? feeValue;

  /// Currency, always `IQD`.
  final String? currency;

  /// The customer's wallet number.
  final String? customerPhone;

  final DateTime? expiryTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  /// The full decoded response payload.
  final Map<String, dynamic> raw;

  /// Convenience flag, `true` when the payment succeeded.
  bool get isSuccess => status == ZainCashTransactionStatus.success;

  /// Builds details from a decoded inquiry response [json].
  factory ZainCashTransactionDetails.fromJson(Map<String, dynamic> json) {
    final details =
        (json['transactionDetails'] as Map?)?.cast<String, dynamic>() ?? {};
    final amount = (details['amount'] as Map?)?.cast<String, dynamic>() ?? {};
    final customer =
        (json['customer'] as Map?)?.cast<String, dynamic>() ?? {};
    final stamps =
        (json['timeStamps'] as Map?)?.cast<String, dynamic>() ?? {};

    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return ZainCashTransactionDetails(
      status: ZainCashTransactionStatus.fromString(json['status']?.toString()),
      transactionId: details['transactionId']?.toString() ?? '',
      operationId: details['operationId']?.toString(),
      externalReferenceId: details['externalReferenceId']?.toString(),
      orderId: details['orderId']?.toString(),
      amount: num.tryParse(amount['value']?.toString() ?? ''),
      feeValue: num.tryParse(amount['feeValue']?.toString() ?? ''),
      currency: amount['currency']?.toString(),
      customerPhone: customer['phone']?.toString(),
      expiryTime: parseDate(stamps['expiryTime'] ?? json['expiryTime']),
      createdAt: parseDate(stamps['createdAt'] ?? json['createdAt']),
      updatedAt: parseDate(stamps['updatedAt']),
      completedAt: parseDate(stamps['completedAt']),
      raw: json,
    );
  }

  @override
  String toString() =>
      'ZainCashTransactionDetails(status: $status, transactionId: '
      '$transactionId, orderId: $orderId, amount: $amount $currency)';
}
