import 'zaincash_callback_event.dart';
import 'zaincash_transaction_details.dart';

/// Outcome of a payment driven by `ZainCashPaymentPage`.
class ZainCashPaymentResult {
  const ZainCashPaymentResult({
    required this.status,
    this.event,
    this.transactionId,
    this.message,
  });

  /// Final transaction status.
  final ZainCashTransactionStatus status;

  /// The decoded callback event, when ZainCash redirected back with a token.
  /// `null` when the user cancelled before completing the payment.
  final ZainCashCallbackEvent? event;

  /// The ZainCash transaction id, when known.
  final String? transactionId;

  /// Failure/cancel reason, when any.
  final String? message;

  /// Convenience flag, `true` when the payment succeeded.
  bool get isSuccess => status == ZainCashTransactionStatus.success;

  /// Builds a result from a decoded callback [event].
  factory ZainCashPaymentResult.fromEvent(ZainCashCallbackEvent event) {
    return ZainCashPaymentResult(
      status: event.status,
      event: event,
      transactionId: event.transactionId,
      message: event.errorMessage,
    );
  }

  /// A result representing a user-cancelled flow (page closed early).
  factory ZainCashPaymentResult.cancelled({String? transactionId}) =>
      ZainCashPaymentResult(
        status: ZainCashTransactionStatus.failed,
        transactionId: transactionId,
        message: 'cancelled',
      );

  @override
  String toString() =>
      'ZainCashPaymentResult(status: $status, transactionId: $transactionId, '
      'message: $message)';
}
