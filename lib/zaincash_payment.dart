/// A Flutter merchant gateway for the ZainCash Payment Gateway API v2
/// (https://docs.zaincash.iq).
///
/// Provides OAuth2 authentication, transaction creation/inquiry/reversal,
/// a ready-to-use WebView payment screen, and callback token decoding.
///
/// For old-style merchant accounts (merchantId + JWT secret on
/// `api.zaincash.iq`), import
/// `package:zaincash_payment/zaincash_payment_legacy.dart` instead.
library;

export 'src/models/zaincash_config.dart';
export 'src/models/zaincash_payment_request.dart';
export 'src/models/zaincash_payment_session.dart';
export 'src/models/zaincash_transaction_details.dart';
export 'src/models/zaincash_callback_event.dart';
export 'src/models/zaincash_reversal_result.dart';
export 'src/models/zaincash_payment_result.dart';
export 'src/zaincash_exception.dart';
export 'src/zaincash_service.dart';
export 'src/zaincash_payment_page.dart';
export 'src/zaincash_payment.dart';
