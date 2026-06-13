import 'package:flutter/material.dart';

import 'models/zaincash_config.dart';
import 'models/zaincash_result.dart';
import 'models/zaincash_transaction.dart';
import 'zaincash_payment_page.dart';

/// Entry point helpers for starting a ZainCash payment.
abstract final class ZainCashPayment {
  /// Pushes the [ZainCashPaymentPage] and resolves with the payment result.
  ///
  /// Returns a [ZainCashResult]; if the user backs out before completing, the
  /// result has [ZainCashStatus.failed] with `msg == 'cancelled'`.
  static Future<ZainCashResult> start(
    BuildContext context, {
    required ZainCashConfig config,
    required ZainCashTransaction transaction,
    String title = 'ZainCash',
  }) async {
    final result = await Navigator.of(context).push<ZainCashResult>(
      MaterialPageRoute(
        builder: (_) => ZainCashPaymentPage(
          config: config,
          transaction: transaction,
          title: title,
        ),
      ),
    );
    return result ?? ZainCashResult.cancelled();
  }
}
