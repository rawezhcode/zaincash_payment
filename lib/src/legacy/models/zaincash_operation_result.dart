/// Result of the processing / pay (OTP) / cancel operations.
///
/// ZainCash responds with `{"success": 1, ...}` on success and
/// `{"success": 0, "error"|"msg": "..."}` on failure.
class ZainCashOperationResult {
  const ZainCashOperationResult({
    required this.success,
    this.transactionId,
    this.message,
    this.raw = const {},
  });

  /// `true` when ZainCash reports `success == 1`.
  final bool success;

  /// The transaction id echoed back, when present.
  final String? transactionId;

  /// Error or status message returned by ZainCash.
  final String? message;

  /// The full decoded response payload.
  final Map<String, dynamic> raw;

  /// Builds a result from a decoded API response [json].
  factory ZainCashOperationResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'];
    return ZainCashOperationResult(
      success: success == 1 || success == '1' || success == true,
      transactionId: json['transactionid']?.toString() ?? json['id']?.toString(),
      message: json['msg']?.toString() ?? json['error']?.toString(),
      raw: json,
    );
  }

  @override
  String toString() =>
      'ZainCashOperationResult(success: $success, message: $message)';
}
