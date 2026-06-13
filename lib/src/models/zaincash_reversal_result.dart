/// Result of reversing (refunding) a transaction
/// (`POST /api/v2/payment-gateway/transaction/reverse`).
class ZainCashReversalResult {
  const ZainCashReversalResult({
    required this.status,
    this.operationId,
    this.referenceId,
    this.reversalReferenceId,
    this.customerMsisdn,
    this.merchantMsisdn,
    this.merchantId,
    this.reason,
    this.amount,
    this.raw = const {},
  });

  /// Reversal status, e.g. `COMPLETED`.
  final String status;

  final String? operationId;

  /// The original transaction reference id.
  final String? referenceId;

  /// The id of the reversal operation itself.
  final String? reversalReferenceId;

  final String? customerMsisdn;
  final String? merchantMsisdn;
  final String? merchantId;

  /// The business reason supplied with the reversal.
  final String? reason;

  /// Reversed amount in IQD.
  final num? amount;

  /// The full decoded response payload.
  final Map<String, dynamic> raw;

  /// Convenience flag, `true` when the reversal completed.
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';

  /// Builds a result from a decoded API response [json].
  factory ZainCashReversalResult.fromJson(Map<String, dynamic> json) {
    return ZainCashReversalResult(
      status: json['status']?.toString() ?? '',
      operationId: json['operationId']?.toString(),
      referenceId: json['referenceId']?.toString(),
      reversalReferenceId: json['reversalReferenceId']?.toString(),
      customerMsisdn: json['customerMsisdn']?.toString(),
      merchantMsisdn: json['merchantMsisdn']?.toString(),
      merchantId: json['merchantId']?.toString(),
      reason: json['reason']?.toString(),
      amount: num.tryParse(json['amount']?.toString() ?? ''),
      raw: json,
    );
  }

  @override
  String toString() =>
      'ZainCashReversalResult(status: $status, amount: $amount, '
      'reversalReferenceId: $reversalReferenceId)';
}
