/// Describes a single payment to be created with ZainCash.
class ZainCashTransaction {
  const ZainCashTransaction({
    required this.amount,
    required this.serviceType,
    required this.orderId,
    this.redirectUrl,
  });

  /// Amount to charge in Iraqi Dinar (IQD). Must be at least the configured
  /// minimum amount (250 by default).
  final num amount;

  /// A short description of the service/product, e.g. `Book`, `Food`,
  /// `Grocery`, `Pharmacy`, `Transportation`, `Other` or your store name.
  /// Max 254 characters.
  final String serviceType;

  /// Merchant order id, required by ZainCash and echoed back in results.
  /// Must be unique per transaction. Max 512 characters.
  final String orderId;

  /// Optional URL ZainCash redirects to after the hosted payment page
  /// completes (the result JWT is appended as `?token=...`).
  ///
  /// Required when using [ZainCashPaymentPage] / the WebView flow. Leave
  /// `null` for the direct API flow (processing + OTP).
  final String? redirectUrl;
}
