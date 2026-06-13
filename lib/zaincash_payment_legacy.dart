/// Legacy ZainCash merchant API (`api.zaincash.iq` / `test.zaincash.iq`).
///
/// Use this library only if your merchant account has the old-style
/// credentials (`merchantId` + JWT `secret` + wallet `msisdn`). New merchant
/// accounts (Client ID / Client Secret, `pg-api.zaincash.iq`) must use the
/// main `package:zaincash_payment/zaincash_payment.dart` library.
library;

export 'src/legacy/models/zaincash_config.dart';
export 'src/legacy/models/zaincash_transaction.dart';
export 'src/legacy/models/zaincash_transaction_details.dart';
export 'src/legacy/models/zaincash_operation_result.dart';
export 'src/legacy/models/zaincash_result.dart';
export 'src/legacy/zaincash_service.dart';
export 'src/legacy/zaincash_payment_page.dart';
export 'src/legacy/zaincash_payment.dart';
export 'src/zaincash_exception.dart';
