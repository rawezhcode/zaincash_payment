import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import 'models/zaincash_config.dart';
import 'models/zaincash_operation_result.dart';
import 'models/zaincash_result.dart';
import 'models/zaincash_transaction.dart';
import 'models/zaincash_transaction_details.dart';
import '../zaincash_exception.dart';

/// Client for the ZainCash merchant API.
///
/// Implements the full transaction lifecycle of the official ZainCash API
/// (https://docs.zaincash.iq):
///
/// 1. [createTransaction] - create a transaction, returns its details/id.
/// 2. [checkTransaction] - check the current status of a transaction.
/// 3. [processingTransaction] - submit the customer wallet number and PIN
///    (ZainCash sends an OTP to the customer by SMS).
/// 4. [payTransaction] - complete the payment with the OTP.
/// 5. [cancelTransaction] - cancel a pending transaction.
///
/// For the hosted-page flow, use [payUrl] with [ZainCashPaymentPage] or your
/// own WebView and decode the redirect with [tryDecodeRedirectUrl].
class ZainCashService {
  ZainCashService(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  final ZainCashConfig config;
  final http.Client _client;

  /// How long signed tokens stay valid (4 hours, per ZainCash docs).
  static const Duration tokenTtl = Duration(hours: 4);

  // ---------------------------------------------------------------------------
  // Step 1 - Create a transaction
  // ---------------------------------------------------------------------------

  /// Creates a transaction and returns its [ZainCashTransactionDetails].
  ///
  /// The returned `id` is required by every follow-up call. Throws a
  /// [ZainCashException] on validation, network, or API errors.
  Future<ZainCashTransactionDetails> createTransaction(
    ZainCashTransaction transaction,
  ) async {
    _validateCreateRequest(transaction);

    final token = signToken(transaction);
    final body = await _postForm(config.initUrl, {
      'token': token,
      'merchantId': config.merchantId,
      'lang': config.lang.code,
    });

    final id = body['id'];
    if (id == null || (id is String && id.isEmpty)) {
      final err = body['err'];
      final message = err is Map ? err['msg']?.toString() : err?.toString();
      throw ZainCashException(
        ZainCashErrorType.apiFailure,
        'ZainCash did not return a transaction id: '
        '${message ?? body.toString()}',
      );
    }

    return ZainCashTransactionDetails.fromJson(body);
  }

  /// Builds and signs the JWT used to create a [transaction].
  ///
  /// Payload: `amount`, `serviceType`, `msisdn`, `orderId` (with the
  /// configured prefix), `redirectUrl`, `iat`, and `exp` (+4h).
  String signToken(ZainCashTransaction transaction) {
    final jwt = JWT({
      'amount': transaction.amount,
      'serviceType': transaction.serviceType,
      'msisdn': config.msisdn,
      'orderId': '${config.prefixOrderId}${transaction.orderId}',
      'redirectUrl': transaction.redirectUrl ?? '',
    });

    return jwt.sign(
      SecretKey(config.secret),
      algorithm: JWTAlgorithm.HS256,
      expiresIn: tokenTtl,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 - Check a transaction
  // ---------------------------------------------------------------------------

  /// Fetches the current details/status of a transaction by [transactionId].
  Future<ZainCashTransactionDetails> checkTransaction(
    String transactionId,
  ) async {
    final token = JWT({
      'id': transactionId,
      'msisdn': config.msisdn,
    }).sign(
      SecretKey(config.secret),
      algorithm: JWTAlgorithm.HS256,
      expiresIn: tokenTtl,
    );

    final body = await _postForm(config.checkUrl, {
      'token': token,
      'merchantId': config.merchantId,
    });

    return ZainCashTransactionDetails.fromJson(body);
  }

  // ---------------------------------------------------------------------------
  // Step 3 - Processing a transaction (sends the OTP)
  // ---------------------------------------------------------------------------

  /// Submits the customer's wallet [phoneNumber] and [pin] for the
  /// transaction. On success, ZainCash sends an OTP to the customer by SMS;
  /// complete the payment with [payTransaction].
  Future<ZainCashOperationResult> processingTransaction({
    required String transactionId,
    required String phoneNumber,
    required String pin,
  }) async {
    _validateProcessing(transactionId, phoneNumber, pin);

    final body = await _postForm(config.processingUrl, {
      'id': transactionId,
      'phonenumber': phoneNumber,
      'pin': pin,
    });

    return ZainCashOperationResult.fromJson(body);
  }

  // ---------------------------------------------------------------------------
  // Step 4 - Complete (pay) a transaction with the OTP
  // ---------------------------------------------------------------------------

  /// Completes the payment using the [otp] the customer received by SMS.
  Future<ZainCashOperationResult> payTransaction({
    required String transactionId,
    required String phoneNumber,
    required String pin,
    required String otp,
  }) async {
    _validateProcessing(transactionId, phoneNumber, pin);
    if (otp.isEmpty) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The OTP is required.',
      );
    }

    final body = await _postForm(config.processingOtpUrl, {
      'id': transactionId,
      'phonenumber': phoneNumber,
      'pin': pin,
      'otp': otp,
    });

    return ZainCashOperationResult.fromJson(body);
  }

  // ---------------------------------------------------------------------------
  // Step 5 - Cancel a transaction
  // ---------------------------------------------------------------------------

  /// Cancels a pending transaction by [transactionId].
  Future<ZainCashOperationResult> cancelTransaction(
    String transactionId,
  ) async {
    final body = await _postForm(config.cancelUrl, {
      'id': transactionId,
      'type': 'MERCHANT_PAYMENT',
    });

    return ZainCashOperationResult.fromJson(body);
  }

  // ---------------------------------------------------------------------------
  // Hosted payment page (WebView) flow
  // ---------------------------------------------------------------------------

  /// Builds the hosted payment page URL for a transaction [id].
  Uri payUrl(String id) => config.payUrl(id);

  /// Verifies and decodes a redirect [token] into a [ZainCashResult].
  ZainCashResult decodeRedirect(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(config.secret));
      final payload = Map<String, dynamic>.from(jwt.payload as Map);
      return ZainCashResult.fromPayload(payload);
    } catch (e) {
      throw ZainCashException(
        ZainCashErrorType.tokenDecode,
        'Failed to verify ZainCash redirect token.',
        cause: e,
      );
    }
  }

  /// Extracts the `token` query parameter from a redirect [url] and decodes
  /// it. Returns `null` when the url has no `token` parameter.
  ZainCashResult? tryDecodeRedirectUrl(String url) {
    final token = Uri.tryParse(url)?.queryParameters['token'];
    if (token == null || token.isEmpty) return null;
    return decodeRedirect(token);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Form-encoded POST shared by all endpoints; decodes the JSON response.
  Future<Map<String, dynamic>> _postForm(
    Uri url,
    Map<String, String> body,
  ) async {
    http.Response response;
    try {
      response = await _client
          .post(url, body: body)
          .timeout(config.timeout == Duration.zero ? const Duration(days: 1) : config.timeout);
    } on TimeoutException catch (e) {
      throw ZainCashException(
        ZainCashErrorType.network,
        'ZainCash request timed out (${url.path}).',
        cause: e,
      );
    } catch (e) {
      throw ZainCashException(
        ZainCashErrorType.network,
        'Failed to reach ZainCash (${url.path}).',
        cause: e,
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ZainCashException(
        ZainCashErrorType.apiFailure,
        'Unexpected response from ZainCash '
        '(status ${response.statusCode}, ${url.path}).',
        cause: e,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final err = decoded['err'];
      final message = err is Map ? err['msg']?.toString() : err?.toString();
      throw ZainCashException(
        ZainCashErrorType.apiFailure,
        'ZainCash error (status ${response.statusCode}): '
        '${message ?? decoded.toString()}',
      );
    }

    return decoded;
  }

  /// Mirrors the official validation rules for creating a transaction.
  void _validateCreateRequest(ZainCashTransaction transaction) {
    if (transaction.amount < config.minAmount) {
      throw ZainCashException(
        ZainCashErrorType.validation,
        'The amount must be at least ${config.minAmount} IQD.',
      );
    }
    if (!RegExp(r'^[0-9]{13}$').hasMatch(config.msisdn)) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The msisdn must be 13 digits, e.g. 9647835077893.',
      );
    }
    if (transaction.serviceType.isEmpty ||
        transaction.serviceType.length > 254) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The serviceType is required (max 254 characters).',
      );
    }
    final orderId = '${config.prefixOrderId}${transaction.orderId}';
    if (transaction.orderId.isEmpty || orderId.length > 512) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The orderId is required (max 512 characters).',
      );
    }
  }

  void _validateProcessing(
    String transactionId,
    String phoneNumber,
    String pin,
  ) {
    if (transactionId.isEmpty) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The transaction id is required.',
      );
    }
    if (!RegExp(r'^[0-9]{13}$').hasMatch(phoneNumber)) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The customer phone number must be 13 digits, e.g. 9647802999569.',
      );
    }
    if (pin.isEmpty) {
      throw const ZainCashException(
        ZainCashErrorType.validation,
        'The PIN is required.',
      );
    }
  }

  /// Releases the underlying HTTP client.
  void dispose() => _client.close();
}
