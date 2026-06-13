/// Lifecycle status of a ZainCash transaction as returned by the
/// create (`transaction/init`) and check (`transaction/get`) endpoints.
enum ZainCashTransactionStatus {
  /// Transaction created, waiting for the customer to pay.
  pending,

  /// Customer credentials accepted, waiting for the OTP confirmation.
  pendingOtp,

  /// Payment completed successfully.
  completed,

  /// Payment failed (expired, not enough balance, ...).
  failed,

  /// The transaction was cancelled.
  cancelled,

  /// Any unrecognized status.
  unknown;

  /// Maps a raw status string from ZainCash to a status value.
  static ZainCashTransactionStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return ZainCashTransactionStatus.pending;
      case 'pending_otp':
        return ZainCashTransactionStatus.pendingOtp;
      case 'completed':
        return ZainCashTransactionStatus.completed;
      case 'failed':
        return ZainCashTransactionStatus.failed;
      case 'cancel':
      case 'cancelled':
        return ZainCashTransactionStatus.cancelled;
      default:
        return ZainCashTransactionStatus.unknown;
    }
  }
}

/// Details of a ZainCash transaction returned by `createTransaction` and
/// `checkTransaction`.
class ZainCashTransactionDetails {
  const ZainCashTransactionDetails({
    required this.id,
    required this.status,
    this.amount,
    this.serviceType,
    this.orderId,
    this.referenceNumber,
    this.from,
    this.operationId,
    this.due,
    this.raw = const {},
  });

  /// The ZainCash transaction id, used by all follow-up calls.
  final String id;

  /// Current lifecycle status of the transaction.
  final ZainCashTransactionStatus status;

  /// Transaction amount in IQD.
  final num? amount;

  /// Service type supplied when the transaction was created.
  final String? serviceType;

  /// The merchant order id (including any configured prefix).
  final String? orderId;

  /// ZainCash reference number, e.g. `RGUR9Q`.
  final String? referenceNumber;

  /// The paying customer's wallet number (available after processing).
  final String? from;

  /// ZainCash operation id (available once completed).
  final String? operationId;

  /// Failure/cancel reason, e.g. `Not enough credit on balance`.
  final String? due;

  /// The full decoded response payload.
  final Map<String, dynamic> raw;

  /// Convenience flag, `true` once the payment is completed.
  bool get isCompleted => status == ZainCashTransactionStatus.completed;

  /// Builds details from a decoded API response [json].
  factory ZainCashTransactionDetails.fromJson(Map<String, dynamic> json) {
    return ZainCashTransactionDetails(
      id: json['id']?.toString() ?? '',
      status: ZainCashTransactionStatus.fromString(json['status']?.toString()),
      amount: num.tryParse(json['amount']?.toString() ?? ''),
      serviceType: json['serviceType']?.toString(),
      orderId: json['orderId']?.toString(),
      referenceNumber: json['referenceNumber']?.toString(),
      from: json['from']?.toString(),
      operationId: json['operationId']?.toString(),
      due: json['due']?.toString(),
      raw: json,
    );
  }

  @override
  String toString() =>
      'ZainCashTransactionDetails(id: $id, status: $status, amount: $amount, '
      'orderId: $orderId, referenceNumber: $referenceNumber, due: $due)';
}
