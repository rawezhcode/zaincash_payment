/// Supported interface languages for the ZainCash payment page.
enum ZainCashLang {
  arabic('ar'),
  english('en'),
  kurdish('ku');

  const ZainCashLang(this.code);

  /// The value sent to the ZainCash API (`ar`, `en`, or `ku`).
  final String code;
}

/// Immutable merchant credentials and environment settings.
///
/// These values are provided by ZainCash when you register a merchant
/// account. The [secret] is used to sign and verify JWT tokens.
///
/// Mirrors the configuration of the official ZainCash API integration
/// (https://docs.zaincash.iq).
class ZainCashConfig {
  const ZainCashConfig({required this.msisdn, required this.merchantId, required this.secret, this.lang = ZainCashLang.arabic, this.isTest = false, this.minAmount = 250, this.prefixOrderId = '', this.timeout = const Duration(seconds: 10)});

  /// The merchant wallet phone number, 13 digits, e.g. `9647835077893`.
  final String msisdn;

  /// The merchant id provided by ZainCash.
  final String merchantId;

  /// The secret used to sign/verify JWT tokens, provided by ZainCash.
  final String secret;

  /// Interface language for the hosted payment page.
  final ZainCashLang lang;

  /// When `true`, the test environment (`test.zaincash.iq`) is used.
  final bool isTest;

  /// Minimum valid transaction amount in Iraqi Dinar (IQD).
  final int minAmount;

  /// Optional prefix prepended to every order id, e.g. `myshop_`.
  final String prefixOrderId;

  /// Timeout applied to every HTTP request to the ZainCash API.
  final Duration timeout;

  /// Base url for the active environment (with trailing slash).
  String get baseUrl => isTest ? 'https://test.zaincash.iq/' : 'https://api.zaincash.iq/';

  /// Endpoint used to create (initialize) a transaction.
  Uri get initUrl => Uri.parse('${baseUrl}transaction/init');

  /// Endpoint used to check a transaction status.
  Uri get checkUrl => Uri.parse('${baseUrl}transaction/get');

  /// Endpoint used to process a transaction (wallet number + PIN, sends OTP).
  Uri get processingUrl => Uri.parse('${baseUrl}transaction/processing');

  /// Endpoint used to complete a transaction with the OTP.
  Uri get processingOtpUrl => Uri.parse('${baseUrl}transaction/processingOTP?type=MERCHANT_PAYMENT');

  /// Endpoint used to cancel a transaction.
  Uri get cancelUrl => Uri.parse('${baseUrl}transaction/cancel');

  /// Builds the hosted payment page URL for a given transaction [id].
  Uri payUrl(String id) => Uri.parse('${baseUrl}transaction/pay?id=$id');
}
