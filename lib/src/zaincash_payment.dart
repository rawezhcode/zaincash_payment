import 'package:flutter/material.dart';

import 'models/zaincash_config.dart';
import 'models/zaincash_payment_request.dart';
import 'models/zaincash_payment_result.dart';
import 'zaincash_payment_page.dart';

/// Entry point helpers for starting a ZainCash payment.
abstract final class ZainCashPayment {
  /// Pushes the [ZainCashPaymentPage] and resolves with the payment result.
  ///
  /// If the user backs out before completing, the result has
  /// `status == ZainCashTransactionStatus.failed` and `message == 'cancelled'`.
  static Future<ZainCashPaymentResult> start(
    BuildContext context, {
    required ZainCashConfig config,
    required ZainCashPaymentRequest request,
    String title = 'ZainCash',
  }) async {
    final result = await Navigator.of(context).push<ZainCashPaymentResult>(
      MaterialPageRoute(
        builder: (_) => ZainCashPaymentPage(
          config: config,
          request: request,
          title: title,
        ),
      ),
    );
    return result ?? ZainCashPaymentResult.cancelled();
  }
}
