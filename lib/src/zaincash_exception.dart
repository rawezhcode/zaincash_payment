/// Categories of failures that can occur during a ZainCash flow.
enum ZainCashErrorType {
  /// Input failed local validation (amount, msisdn, orderId, ...).
  validation,

  /// OAuth2 authentication with ZainCash failed (bad client credentials).
  auth,

  /// A network/transport error reaching the ZainCash API.
  network,

  /// The API returned an error response or an unexpected payload.
  apiFailure,

  /// The redirect/init token could not be decoded or verified.
  tokenDecode,
}

/// Error thrown by the ZainCash gateway.
class ZainCashException implements Exception {
  const ZainCashException(
    this.type,
    this.message, {
    this.cause,
  });

  /// The category of the failure.
  final ZainCashErrorType type;

  /// Human readable description of the failure.
  final String message;

  /// The original error/exception, if any.
  final Object? cause;

  @override
  String toString() => 'ZainCashException($type): $message';
}
