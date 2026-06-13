import 'zaincash_transaction_details.dart';

/// Decoded payload of the JWT token ZainCash appends to your
/// `successUrl`/`failureUrl` (and sends to your webhook).
class ZainCashCallbackEvent {
  const ZainCashCallbackEvent({
    required this.status,
    required this.verified,
    this.eventType,
    this.eventId,
    this.transactionId,
    this.orderId,
    this.customerMsisdn,
    this.operationId,
    this.serviceType,
    this.errorMessage,
    this.previousStatus,
    this.amount,
    this.currency,
    this.feeValue,
    this.timestamp,
    this.raw = const {},
  });

  /// The transaction status after the payment (`data.currentStatus`).
  final ZainCashTransactionStatus status;

  /// `true` when the JWT signature was verified with your key. When `false`
  /// the payload was decoded without verification; confirm the result with
  /// `ZainCashService.checkTransaction` before fulfilling the order.
  final bool verified;

  /// Event type, e.g. `STATUS_CHANGED`.
  final String? eventType;

  /// Unique event id; process each id only once.
  final String? eventId;

  /// The ZainCash transaction id.
  final String? transactionId;

  /// Your order id echoed back.
  final String? orderId;

  /// The customer's wallet number. Store it and pass it as
  /// `customerPhone` on the customer's next payment.
  final String? customerMsisdn;

  /// ZainCash operation id.
  final String? operationId;

  /// The service type supplied when the transaction was created.
  final String? serviceType;

  /// Failure reason when the payment did not succeed.
  final String? errorMessage;

  /// The status before this event (`data.previousStatus`).
  final ZainCashTransactionStatus? previousStatus;

  /// Transaction amount.
  final num? amount;

  /// Currency, always `IQD`.
  final String? currency;

  /// Fee charged for the transaction.
  final num? feeValue;

  /// When the event was emitted.
  final DateTime? timestamp;

  /// The full decoded JWT payload.
  final Map<String, dynamic> raw;

  /// Convenience flag, `true` when the payment succeeded.
  bool get isSuccess => status == ZainCashTransactionStatus.success;

  /// Builds an event from a decoded JWT [payload].
  factory ZainCashCallbackEvent.fromPayload(
    Map<String, dynamic> payload, {
    required bool verified,
  }) {
    final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final amount = (data['amount'] as Map?)?.cast<String, dynamic>() ?? {};

    return ZainCashCallbackEvent(
      status:
          ZainCashTransactionStatus.fromString(data['currentStatus']?.toString()),
      verified: verified,
      eventType: payload['eventType']?.toString(),
      eventId: payload['eventId']?.toString(),
      transactionId: data['transactionId']?.toString(),
      orderId: data['orderId']?.toString(),
      customerMsisdn: data['customerMsisdn']?.toString(),
      operationId: data['operationId']?.toString(),
      serviceType: data['serviceType']?.toString(),
      errorMessage: data['errorMessage']?.toString(),
      previousStatus: data['previousStatus'] == null
          ? null
          : ZainCashTransactionStatus.fromString(
              data['previousStatus'].toString()),
      amount: num.tryParse(amount['value']?.toString() ?? ''),
      currency: amount['currency']?.toString(),
      feeValue: num.tryParse(amount['feeValue']?.toString() ?? ''),
      timestamp: DateTime.tryParse(payload['timestamp']?.toString() ?? ''),
      raw: payload,
    );
  }

  @override
  String toString() =>
      'ZainCashCallbackEvent(status: $status, transactionId: $transactionId, '
      'orderId: $orderId, verified: $verified, errorMessage: $errorMessage)';
}
