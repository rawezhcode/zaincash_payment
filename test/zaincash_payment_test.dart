import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zaincash_payment/zaincash_payment.dart';

void main() {
  const config = ZainCashConfig(
    clientId: 'test-client-id',
    clientSecret: 'test-client-secret',
    lang: ZainCashLang.english,
    isTest: true,
  );

  const request = ZainCashPaymentRequest(
    amount: 500,
    orderId: 'moi-21323123vc',
    serviceType: 'Delivery',
    successUrl: 'https://example.com/success',
    failureUrl: 'https://example.com/failure',
  );

  http.Response tokenResponse() => http.Response(
        jsonEncode({
          'access_token': 'test-access-token',
          'scope': 'payment:write payment:read',
          'token_type': 'Bearer',
          'expires_in': 86399,
        }),
        200,
      );

  group('environment urls', () {
    test('test env uses the UAT host', () {
      expect(config.tokenUrl.toString(),
          'https://pg-api-uat.zaincash.iq/oauth2/token');
      expect(config.initUrl.toString(),
          'https://pg-api-uat.zaincash.iq/api/v2/payment-gateway/transaction/init');
      expect(config.inquiryUrl('tx-1').toString(),
          'https://pg-api-uat.zaincash.iq/api/v2/payment-gateway/transaction/inquiry/tx-1');
      expect(config.reverseUrl.toString(),
          'https://pg-api-uat.zaincash.iq/api/v2/payment-gateway/transaction/reverse');
    });

    test('production env uses the onboarding-provided base url', () {
      const prod = ZainCashConfig(
        clientId: 'c',
        clientSecret: 's',
        isTest: false,
        productionBaseUrl: 'https://pg-api.zaincash.iq/',
      );
      expect(prod.tokenUrl.toString(),
          'https://pg-api.zaincash.iq/oauth2/token');
    });
  });

  group('getAccessToken', () {
    test('requests a client_credentials token with scope', () async {
      late Map<String, String> sentBody;
      final client = MockClient((req) async {
        expect(req.url.path, '/oauth2/token');
        sentBody = Uri.splitQueryString(req.body);
        return tokenResponse();
      });

      final service = ZainCashService(config, client: client);
      final token = await service.getAccessToken();

      expect(token, 'test-access-token');
      expect(sentBody, {
        'grant_type': 'client_credentials',
        'client_id': 'test-client-id',
        'client_secret': 'test-client-secret',
        'scope': 'payment:read payment:write',
      });
    });

    test('caches the token until it expires', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return tokenResponse();
      });

      final service = ZainCashService(config, client: client);
      await service.getAccessToken();
      await service.getAccessToken();

      expect(calls, 1);
    });

    test('throws auth error on invalid_client', () async {
      final client = MockClient((req) async {
        return http.Response(jsonEncode({'error': 'invalid_client'}), 401);
      });

      final service = ZainCashService(config, client: client);
      expect(
        () => service.getAccessToken(),
        throwsA(isA<ZainCashException>()
            .having((e) => e.type, 'type', ZainCashErrorType.auth)),
      );
    });
  });

  group('createTransaction', () {
    test('sends the documented JSON body and parses the session', () async {
      late Map<String, dynamic> sentJson;
      final client = MockClient((req) async {
        if (req.url.path == '/oauth2/token') return tokenResponse();

        expect(req.url.path, '/api/v2/payment-gateway/transaction/init');
        expect(req.headers['Authorization'], 'Bearer test-access-token');
        sentJson = jsonDecode(req.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'status': 'SUCCESS',
            'transactionDetails': {
              'transactionId': '9da792d5-f818-4e98-9fb6-6c0b13902c8b',
              'externalReferenceId': sentJson['externalReferenceId'],
              'orderId': 'moi-21323123vc',
              'amount': {'currency': 'IQD', 'value': 500},
            },
            'redirectUrl':
                'https://pg-api-uat.zaincash.iq/transaction/pay?id=tx&token=tok',
            'expiryTime': '2025-12-22T08:04:27.402+00:00',
            'createdAt': '2025-12-22T07:49:28.540+00:00',
          }),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final session = await service.createTransaction(request);

      expect(sentJson['language'], 'en');
      expect(sentJson['orderId'], 'moi-21323123vc');
      expect(sentJson['serviceType'], 'Delivery');
      expect(sentJson['amount'], {'value': '500', 'currency': 'IQD'});
      expect(sentJson['redirectUrls'], {
        'successUrl': 'https://example.com/success',
        'failureUrl': 'https://example.com/failure',
      });
      expect(sentJson['externalReferenceId'], isNotEmpty);
      expect(sentJson.containsKey('customer'), isFalse);

      expect(session.transactionId, '9da792d5-f818-4e98-9fb6-6c0b13902c8b');
      expect(session.status, ZainCashTransactionStatus.success);
      expect(session.redirectUrl, contains('/transaction/pay'));
      expect(session.amount, 500);
    });

    test('includes customer phone when provided', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/oauth2/token') return tokenResponse();
        final json = jsonDecode(req.body) as Map<String, dynamic>;
        expect(json['customer'], {'phone': '9647802999569'});
        return http.Response(
          jsonEncode({
            'status': 'SUCCESS',
            'transactionDetails': {'transactionId': 'tx-1'},
            'redirectUrl': 'https://pay.example/x',
          }),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      await service.createTransaction(const ZainCashPaymentRequest(
        amount: 500,
        orderId: 'o-1',
        serviceType: 'Delivery',
        successUrl: 'https://example.com/success',
        failureUrl: 'https://example.com/failure',
        customerPhone: '9647802999569',
      ));
    });

    test('throws apiFailure on error responses', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/oauth2/token') return tokenResponse();
        return http.Response(
          jsonEncode({'message': 'PAYMENT_GATEWAY_UNAUTHORIZED'}),
          403,
        );
      });

      final service = ZainCashService(config, client: client);
      expect(
        () => service.createTransaction(request),
        throwsA(isA<ZainCashException>()
            .having((e) => e.type, 'type', ZainCashErrorType.apiFailure)),
      );
    });
  });

  group('checkTransaction', () {
    test('parses the inquiry response', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/oauth2/token') return tokenResponse();

        expect(req.method, 'GET');
        expect(req.url.path,
            '/api/v2/payment-gateway/transaction/inquiry/tx-1');

        return http.Response(
          jsonEncode({
            'status': 'OTP_SENT',
            'transactionDetails': {
              'transactionId': 'tx-1',
              'operationId': null,
              'externalReferenceId': 'ext-1',
              'orderId': 'moi-21323123vc',
              'amount': {'currency': 'IQD', 'value': 500, 'feeValue': 0},
            },
            'customer': {'phone': '9647802999569'},
            'timeStamps': {
              'expiryTime': '2025-12-22T08:04:27.403+00:00',
              'createdAt': '2025-12-22T07:49:28.540+00:00',
              'updatedAt': '2025-12-22T07:49:29.003+00:00',
              'completedAt': null,
            },
          }),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final details = await service.checkTransaction('tx-1');

      expect(details.status, ZainCashTransactionStatus.otpSent);
      expect(details.transactionId, 'tx-1');
      expect(details.amount, 500);
      expect(details.feeValue, 0);
      expect(details.customerPhone, '9647802999569');
      expect(details.completedAt, isNull);
      expect(details.createdAt, isNotNull);
    });

    test('parses every documented status', () {
      expect(ZainCashTransactionStatus.fromString('SUCCESS'),
          ZainCashTransactionStatus.success);
      expect(ZainCashTransactionStatus.fromString('FAILED'),
          ZainCashTransactionStatus.failed);
      expect(ZainCashTransactionStatus.fromString('PENDING'),
          ZainCashTransactionStatus.pending);
      expect(ZainCashTransactionStatus.fromString('OTP_SENT'),
          ZainCashTransactionStatus.otpSent);
      expect(
          ZainCashTransactionStatus.fromString(
              'CUSTOMER_AUTHENTICATION_REQUIRED'),
          ZainCashTransactionStatus.customerAuthenticationRequired);
      expect(ZainCashTransactionStatus.fromString('EXPIRED'),
          ZainCashTransactionStatus.expired);
      expect(ZainCashTransactionStatus.fromString('REFUNDED'),
          ZainCashTransactionStatus.refunded);
    });
  });

  group('reverseTransaction', () {
    test('posts transactionId and reason', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/oauth2/token') return tokenResponse();

        expect(req.url.path, '/api/v2/payment-gateway/transaction/reverse');
        final json = jsonDecode(req.body) as Map<String, dynamic>;
        expect(json, {'transactionId': 'tx-1', 'reason': 'customer request'});

        return http.Response(
          jsonEncode({
            'id': 252,
            'operationId': 1253032369964175,
            'referenceId': 'tx-1',
            'reversalReferenceId': '89da0fa7-040c-4101-9d90-66c301019312',
            'status': 'COMPLETED',
            'reason': 'customer request',
            'amount': 500,
          }),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final result = await service.reverseTransaction(
        transactionId: 'tx-1',
        reason: 'customer request',
      );

      expect(result.isCompleted, isTrue);
      expect(result.amount, 500);
      expect(result.referenceId, 'tx-1');
    });
  });

  group('callback token decoding', () {
    final payload = {
      'eventType': 'STATUS_CHANGED',
      'eventId': '812691e6-b433-4ffc-888c-d11e21c14994',
      'timestamp': '2023-10-27T10:15:30.000+00:00',
      'data': {
        'transactionId': '6fc49988-c618-4ee4-880b-d5a169693296',
        'customerMsisdn': '9647802999569',
        'orderId': 'moi-21323123vc',
        'serviceType': 'Delivery',
        'errorMessage': null,
        'previousStatus': 'PENDING',
        'currentStatus': 'SUCCESS',
        'amount': {'currency': 'IQD', 'value': 5000, 'feeValue': 0},
      },
    };

    test('verifies with the apiKey when provided', () {
      const cfg = ZainCashConfig(
        clientId: 'c',
        clientSecret: 's',
        apiKey: 'my-api-key',
        isTest: true,
      );
      final service = ZainCashService(cfg);
      final token = JWT(payload).sign(SecretKey('my-api-key'));

      final event = service.decodeCallbackToken(token);

      expect(event.verified, isTrue);
      expect(event.isSuccess, isTrue);
      expect(event.status, ZainCashTransactionStatus.success);
      expect(event.previousStatus, ZainCashTransactionStatus.pending);
      expect(event.transactionId, '6fc49988-c618-4ee4-880b-d5a169693296');
      expect(event.customerMsisdn, '9647802999569');
      expect(event.amount, 5000);
    });

    test('falls back to client secret for verification', () {
      final service = ZainCashService(config);
      final token = JWT(payload).sign(SecretKey('test-client-secret'));

      final event = service.decodeCallbackToken(token);
      expect(event.verified, isTrue);
    });

    test('decodes unverified when no key matches', () {
      final service = ZainCashService(config);
      final token = JWT(payload).sign(SecretKey('some-other-key'));

      final event = service.decodeCallbackToken(token);
      expect(event.verified, isFalse);
      expect(event.status, ZainCashTransactionStatus.success);
    });

    test('extracts the token from a redirect url', () {
      final service = ZainCashService(config);
      final token = JWT(payload).sign(SecretKey('test-client-secret'));
      final event = service
          .tryDecodeRedirectUrl('https://example.com/success?token=$token');

      expect(event, isNotNull);
      expect(event!.isSuccess, isTrue);
    });

    test('returns null when redirect url has no token', () {
      final service = ZainCashService(config);
      expect(
          service.tryDecodeRedirectUrl('https://example.com/success'), isNull);
    });
  });
}
