/// Outcome of a ZainCash payment as reported by the redirect token.
enum ZainCashStatus {
  success,
  failed,
  pending,
  unknown;

  /// Maps a raw status string from ZainCash to a [ZainCashStatus].
  static ZainCashStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'success':
        return ZainCashStatus.success;
      case 'failed':
        return ZainCashStatus.failed;
      case 'pending':
        return ZainCashStatus.pending;
      default:
        return ZainCashStatus.unknown;
    }
  }
}

/// Decoded result of a ZainCash transaction.
class ZainCashResult {
  const ZainCashResult({
    required this.status,
    this.transactionId,
    this.orderId,
    this.msg,
    this.raw = const {},
  });

  /// Payment status reported by ZainCash.
  final ZainCashStatus status;

  /// The ZainCash transaction id.
  final String? transactionId;

  /// The merchant order id echoed back, if one was supplied.
  final String? orderId;

  /// Human readable message describing the outcome.
  final String? msg;

  /// The full decoded JWT payload.
  final Map<String, dynamic> raw;

  /// Convenience flag for a successful payment.
  bool get isSuccess => status == ZainCashStatus.success;

  /// Builds a result from a decoded redirect JWT [payload].
  factory ZainCashResult.fromPayload(Map<String, dynamic> payload) {
    return ZainCashResult(
      status: ZainCashStatus.fromString(payload['status']?.toString()),
      transactionId: payload['id']?.toString(),
      orderId: payload['orderid']?.toString() ?? payload['orderId']?.toString(),
      msg: payload['msg']?.toString(),
      raw: payload,
    );
  }

  /// A result representing a user-cancelled flow (no token received).
  factory ZainCashResult.cancelled() =>
      const ZainCashResult(status: ZainCashStatus.failed, msg: 'cancelled');

  @override
  String toString() =>
      'ZainCashResult(status: $status, transactionId: $transactionId, '
      'orderId: $orderId, msg: $msg)';
}
