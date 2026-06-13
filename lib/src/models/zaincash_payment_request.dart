import 'zaincash_config.dart';

/// Describes a payment to be created with the ZainCash Payment Gateway v2.
class ZainCashPaymentRequest {
  const ZainCashPaymentRequest({
    required this.amount,
    required this.orderId,
    required this.serviceType,
    required this.successUrl,
    required this.failureUrl,
    this.customerPhone,
    this.externalReferenceId,
    this.lang,
  });

  /// Transaction amount in Iraqi Dinar (IQD).
  final num amount;

  /// Your internal order identifier.
  final String orderId;

  /// Merchant-defined service identifier, e.g. `Delivery`.
  final String serviceType;

  /// Where the customer is redirected after a successful payment
  /// (the result JWT is appended as `?token=...`).
  final String successUrl;

  /// Where the customer is redirected after a failure or cancel.
  final String failureUrl;

  /// Customer wallet number in international format (e.g. `96477...`).
  /// Omit on first payment; ZainCash prompts the customer for it.
  final String? customerPhone;

  /// Unique id (UUID) per payment attempt, used for idempotency.
  /// Auto-generated when `null`.
  final String? externalReferenceId;

  /// Overrides the config language for this payment.
  final ZainCashLang? lang;
}
