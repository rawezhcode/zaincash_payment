import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import 'models/zaincash_callback_event.dart';
import 'models/zaincash_config.dart';
import 'models/zaincash_payment_request.dart';
import 'models/zaincash_payment_session.dart';
import 'models/zaincash_reversal_result.dart';
import 'models/zaincash_transaction_details.dart';
import 'utils/uuid.dart';
import 'zaincash_exception.dart';

/// Client for the ZainCash Payment Gateway API v2
/// (https://docs.zaincash.iq).
///
/// Flow:
///
/// 1. [createTransaction] - authenticates (OAuth2) and creates a payment;
///    returns a [ZainCashPaymentSession] with the hosted page `redirectUrl`.
/// 2. Redirect the customer to `session.redirectUrl` (or use
///    `ZainCashPaymentPage`, which does this in a WebView).
/// 3. ZainCash redirects back to your `successUrl`/`failureUrl` with a JWT
///    token; decode it with [tryDecodeRedirectUrl] / [decodeCallbackToken].
/// 4. Confirm the final status with [checkTransaction] (inquiry).
/// 5. Optionally refund with [reverseTransaction] (needs `reverse:write`
///    scope).
class ZainCashService {
  ZainCashService(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  final ZainCashConfig config;
  final http.Client _client;

  String? _accessToken;
  DateTime? _accessTokenExpiry;

  // ---------------------------------------------------------------------------
  // OAuth2
  // ---------------------------------------------------------------------------

  /// Returns a valid OAuth2 access token, requesting a new one when the
  /// cached token is missing or about to expire.
  Future<String> getAccessToken() async {
    final token = _accessToken;
    final expiry = _accessTokenExpiry;
    if (token != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 1)))) {
      return token;
    }

    final response = await _send(() => _client.post(
          config.tokenUrl,
          body: {
            'grant_type': 'client_credentials',
            'client_id': config.clientId,
            'client_secret': config.clientSecret,
            'scope': config.scope,
          },
        ));

    final body = _decodeJson(response, config.tokenUrl);
    final accessToken = body['access_token']?.toString();
    if (response.statusCode != 200 || accessToken == null) {
      throw ZainCashException(
        ZainCashErrorType.auth,
        'ZainCash authentication failed '
        '(status ${response.statusCode}): '
        '${body['error_description'] ?? body['error'] ?? response.body}',
      );
    }

    final expiresIn =
        int.tryParse(body['expires_in']?.toString() ?? '') ?? 3600;
    _accessToken = accessToken;
    _accessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    return accessToken;
  }

  // ---------------------------------------------------------------------------
  // Create payment
  // ---------------------------------------------------------------------------

  /// Creates a payment and returns the session containing the hosted page
  /// `redirectUrl` and the `transactionId`.
  Future<ZainCashPaymentSession> createTransaction(
    ZainCashPaymentRequest request,
  ) async {
    if (request.amount <= 0) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The amount must be greater than zero.',
      );
    }
    if (request.orderId.isEmpty || request.serviceType.isEmpty) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'orderId and serviceType are required.',
      );
    }

    final token = await getAccessToken();
    final payload = <String, dynamic>{
      'language': (request.lang ?? config.lang).code,
      'externalReferenceId': request.externalReferenceId ?? generateUuidV4(),
      'orderId': request.orderId,
      'serviceType': request.serviceType,
      'amount': {
        'value': request.amount.toString(),
        'currency': 'IQD',
      },
      if (request.customerPhone != null && request.customerPhone!.isNotEmpty)
        'customer': {'phone': request.customerPhone},
      'redirectUrls': {
        'successUrl': request.successUrl,
        'failureUrl': request.failureUrl,
      },
    };

    final response = await _send(() => _client.post(
          config.initUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        ));

    final body = _checkResponse(response, config.initUrl);
    final session = ZainCashPaymentSession.fromJson(body);
    if (session.transactionId.isEmpty || session.redirectUrl.isEmpty) {
      throw ZainCashException(
        ZainCashErrorType.apiFailure,
        'ZainCash did not return a transaction id / redirect url: $body',
      );
    }
    return session;
  }

  // ---------------------------------------------------------------------------
  // Inquiry
  // ---------------------------------------------------------------------------

  /// Fetches the current status/details of a transaction by [transactionId].
  Future<ZainCashTransactionDetails> checkTransaction(
    String transactionId,
  ) async {
    final token = await getAccessToken();
    final url = config.inquiryUrl(transactionId);

    final response = await _send(() => _client.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        ));

    return ZainCashTransactionDetails.fromJson(_checkResponse(response, url));
  }

  // ---------------------------------------------------------------------------
  // Reverse (refund)
  // ---------------------------------------------------------------------------

  /// Reverses (refunds) a successful transaction. Requires the
  /// `reverse:write` scope in [ZainCashConfig.scope].
  Future<ZainCashReversalResult> reverseTransaction({
    required String transactionId,
    required String reason,
  }) async {
    final token = await getAccessToken();

    final response = await _send(() => _client.post(
          config.reverseUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'transactionId': transactionId,
            'reason': reason,
          }),
        ));

    return ZainCashReversalResult.fromJson(
        _checkResponse(response, config.reverseUrl));
  }

  // ---------------------------------------------------------------------------
  // Redirect / webhook token decoding
  // ---------------------------------------------------------------------------

  /// Decodes the JWT [token] ZainCash appended to your success/failure URL
  /// (or sent to your webhook).
  ///
  /// The signature is verified with [ZainCashConfig.apiKey] (falling back to
  /// the client secret). If verification fails, the payload is decoded
  /// without verification and the event is flagged `verified == false`; in
  /// that case confirm the result with [checkTransaction].
  ZainCashCallbackEvent decodeCallbackToken(String token) {
    final keys = [
      if (config.apiKey != null && config.apiKey!.isNotEmpty) config.apiKey!,
      config.clientSecret,
    ];

    for (final key in keys) {
      try {
        final jwt = JWT.verify(token, SecretKey(key));
        return ZainCashCallbackEvent.fromPayload(
          Map<String, dynamic>.from(jwt.payload as Map),
          verified: true,
        );
      } on JWTException {
        continue;
      }
    }

    try {
      final jwt = JWT.decode(token);
      return ZainCashCallbackEvent.fromPayload(
        Map<String, dynamic>.from(jwt.payload as Map),
        verified: false,
      );
    } catch (e) {
      throw ZainCashException(
        ZainCashErrorType.tokenDecode,
        'Failed to decode ZainCash callback token.',
        cause: e,
      );
    }
  }

  /// Extracts the `token` query parameter from a redirect [url] and decodes
  /// it. Returns `null` when the url has no `token` parameter.
  ZainCashCallbackEvent? tryDecodeRedirectUrl(String url) {
    final token = Uri.tryParse(url)?.queryParameters['token'];
    if (token == null || token.isEmpty) return null;
    return decodeCallbackToken(token);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(config.timeout);
    } on TimeoutException catch (e) {
      throw ZainCashException(
        ZainCashErrorType.network,
        'ZainCash request timed out.',
        cause: e,
      );
    } on ZainCashException {
      rethrow;
    } catch (e) {
      throw ZainCashException(
        ZainCashErrorType.network,
        'Failed to reach ZainCash.',
        cause: e,
      );
    }
  }

  Map<String, dynamic> _decodeJson(http.Response response, Uri url) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ZainCashException(
        ZainCashErrorType.apiFailure,
        'Unexpected response from ZainCash '
        '(status ${response.statusCode}, ${url.path}).',
        cause: e,
      );
    }
  }

  Map<String, dynamic> _checkResponse(http.Response response, Uri url) {
    final body = _decodeJson(response, url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ZainCashException(
        response.statusCode == 401
            ? ZainCashErrorType.auth
            : ZainCashErrorType.apiFailure,
        'ZainCash error (status ${response.statusCode}, ${url.path}): '
        '${body['message'] ?? body['error'] ?? body.toString()}',
      );
    }
    return body;
  }

  /// Releases the underlying HTTP client.
  void dispose() => _client.close();
}
