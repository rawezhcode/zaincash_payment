/// Supported interface languages for the ZainCash payment page.
enum ZainCashLang {
  arabic('ar'),
  english('en'),
  kurdish('ku');

  const ZainCashLang(this.code);

  /// The value sent to the ZainCash API (`ar`, `en`, or `ku`).
  final String code;
}

/// Merchant credentials and environment settings for the ZainCash
/// Payment Gateway API v2 (https://docs.zaincash.iq).
///
/// New merchant accounts receive a **Client ID** and **Client Secret**
/// (OAuth2 client credentials) plus the production API link, e.g.
/// `https://pg-api.zaincash.iq`.
class ZainCashConfig {
  const ZainCashConfig({
    required this.clientId,
    required this.clientSecret,
    this.apiKey,
    this.lang = ZainCashLang.arabic,
    this.isTest = false,
    this.productionBaseUrl = 'https://pg-api.zaincash.iq',
    this.scope = 'payment:read payment:write',
    this.timeout = const Duration(seconds: 15),
  });

  /// OAuth2 Client ID provided by ZainCash.
  final String clientId;

  /// OAuth2 Client Secret provided by ZainCash.
  final String clientSecret;

  /// API (secret) key used to verify the redirect/webhook JWT tokens.
  ///
  /// When `null`, [clientSecret] is tried instead, and if verification still
  /// fails the token payload is decoded without verification (the result is
  /// flagged as unverified).
  final String? apiKey;

  /// Interface language for the hosted payment page.
  final ZainCashLang lang;

  /// When `true`, the UAT environment (`pg-api-uat.zaincash.iq`) is used.
  final bool isTest;

  /// Production base URL, provided by ZainCash during onboarding.
  final String productionBaseUrl;

  /// OAuth2 scopes requested with the access token. Add `reverse:write`
  /// if you use [ZainCashService.reverseTransaction].
  final String scope;

  /// Timeout applied to every HTTP request to the ZainCash API.
  final Duration timeout;

  /// Base url for the active environment (no trailing slash).
  String get baseUrl {
    final url =
        isTest ? 'https://pg-api-uat.zaincash.iq' : productionBaseUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// OAuth2 token endpoint.
  Uri get tokenUrl => Uri.parse('$baseUrl/oauth2/token');

  /// Endpoint used to create (initialize) a payment transaction.
  Uri get initUrl =>
      Uri.parse('$baseUrl/api/v2/payment-gateway/transaction/init');

  /// Endpoint used to inquire about a transaction status.
  Uri inquiryUrl(String transactionId) => Uri.parse(
      '$baseUrl/api/v2/payment-gateway/transaction/inquiry/$transactionId');

  /// Endpoint used to reverse (refund) a transaction.
  Uri get reverseUrl =>
      Uri.parse('$baseUrl/api/v2/payment-gateway/transaction/reverse');
}
