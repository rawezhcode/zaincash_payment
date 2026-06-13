import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zaincash_payment/zaincash_payment_legacy.dart';

void main() {
  const config = ZainCashConfig(
    msisdn: '9647835077893',
    merchantId: '5ffacf6612b5777c6d44266f',
    secret: 'test-secret',
    lang: ZainCashLang.english,
    isTest: true,
    prefixOrderId: 'shop_',
  );

  const transaction = ZainCashTransaction(
    amount: 1000,
    serviceType: 'Book',
    orderId: 'order-123',
    redirectUrl: 'https://example.com/return',
  );

  group('environment urls', () {
    test('test env uses test host with all endpoints', () {
      expect(config.initUrl.toString(),
          'https://test.zaincash.iq/transaction/init');
      expect(config.checkUrl.toString(),
          'https://test.zaincash.iq/transaction/get');
      expect(config.processingUrl.toString(),
          'https://test.zaincash.iq/transaction/processing');
      expect(config.processingOtpUrl.toString(),
          'https://test.zaincash.iq/transaction/processingOTP?type=MERCHANT_PAYMENT');
      expect(config.cancelUrl.toString(),
          'https://test.zaincash.iq/transaction/cancel');
      expect(config.payUrl('abc').toString(),
          'https://test.zaincash.iq/transaction/pay?id=abc');
    });

    test('production env uses api host', () {
      const prod = ZainCashConfig(
        msisdn: '9647835077893',
        merchantId: 'm',
        secret: 's',
        isTest: false,
      );
      expect(prod.initUrl.toString(),
          'https://api.zaincash.iq/transaction/init');
    });
  });

  group('signToken', () {
    test('payload matches the official ZainCash structure', () {
      final service = ZainCashService(config);
      final token = service.signToken(transaction);
      final jwt = JWT.verify(token, SecretKey(config.secret));
      final payload = jwt.payload as Map;

      expect(payload['amount'], 1000);
      expect(payload['serviceType'], 'Book');
      expect(payload['msisdn'], '9647835077893');
      expect(payload['orderId'], 'shop_order-123');
      expect(payload['redirectUrl'], 'https://example.com/return');
      expect(payload['iat'], isNotNull);
      expect(payload['exp'], isNotNull);
    });
  });

  group('createTransaction', () {
    test('posts form data and parses the transaction details', () async {
      late Map<String, String> sentBody;
      final client = MockClient((request) async {
        sentBody = Uri.splitQueryString(request.body);
        expect(request.url.toString(),
            'https://test.zaincash.iq/transaction/init');
        return http.Response(
          jsonEncode({
            'id': '655874c00227c4d2ec58f710',
            'status': 'pending',
            'amount': '1000',
            'serviceType': 'Book',
            'orderId': 'shop_order-123',
            'referenceNumber': 'RGUR9Q',
          }),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final details = await service.createTransaction(transaction);

      expect(sentBody['merchantId'], config.merchantId);
      expect(sentBody['lang'], 'en');
      expect(sentBody['token'], isNotEmpty);

      expect(details.id, '655874c00227c4d2ec58f710');
      expect(details.status, ZainCashTransactionStatus.pending);
      expect(details.amount, 1000);
      expect(details.referenceNumber, 'RGUR9Q');
    });

    test('throws apiFailure with err.msg when no id returned', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'err': {'msg': 'Invalid merchant'},
          }),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      expect(
        () => service.createTransaction(transaction),
        throwsA(isA<ZainCashException>().having(
            (e) => e.type, 'type', ZainCashErrorType.apiFailure)),
      );
    });

    test('validates amount, msisdn, and orderId locally', () {
      final service = ZainCashService(config, client: MockClient((_) async {
        fail('must not reach the network');
      }));

      expect(
        () => service.createTransaction(const ZainCashTransaction(
          amount: 100,
          serviceType: 'Book',
          orderId: 'o',
        )),
        throwsA(isA<ZainCashException>().having(
            (e) => e.type, 'type', ZainCashErrorType.validation)),
      );

      expect(
        () => service.createTransaction(const ZainCashTransaction(
          amount: 1000,
          serviceType: 'Book',
          orderId: '',
        )),
        throwsA(isA<ZainCashException>().having(
            (e) => e.type, 'type', ZainCashErrorType.validation)),
      );
    });
  });

  group('checkTransaction', () {
    test('signs the check token and parses the status', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://test.zaincash.iq/transaction/get');
        final body = Uri.splitQueryString(request.body);
        final jwt = JWT.verify(body['token']!, SecretKey(config.secret));
        final payload = jwt.payload as Map;
        expect(payload['id'], 'tx-1');
        expect(payload['msisdn'], config.msisdn);

        return http.Response(
          jsonEncode({'id': 'tx-1', 'status': 'completed'}),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final details = await service.checkTransaction('tx-1');

      expect(details.status, ZainCashTransactionStatus.completed);
      expect(details.isCompleted, isTrue);
    });

    test('parses every documented status', () {
      expect(ZainCashTransactionStatus.fromString('pending'),
          ZainCashTransactionStatus.pending);
      expect(ZainCashTransactionStatus.fromString('pending_otp'),
          ZainCashTransactionStatus.pendingOtp);
      expect(ZainCashTransactionStatus.fromString('completed'),
          ZainCashTransactionStatus.completed);
      expect(ZainCashTransactionStatus.fromString('failed'),
          ZainCashTransactionStatus.failed);
      expect(ZainCashTransactionStatus.fromString('cancel'),
          ZainCashTransactionStatus.cancelled);
    });
  });

  group('processing / pay / cancel', () {
    test('processingTransaction posts id, phonenumber, pin', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://test.zaincash.iq/transaction/processing');
        final body = Uri.splitQueryString(request.body);
        expect(body, {
          'id': 'tx-1',
          'phonenumber': '9647802999569',
          'pin': '1234',
        });
        return http.Response(
          jsonEncode({'success': 1, 'transactionid': 'tx-1'}),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final result = await service.processingTransaction(
        transactionId: 'tx-1',
        phoneNumber: '9647802999569',
        pin: '1234',
      );

      expect(result.success, isTrue);
      expect(result.transactionId, 'tx-1');
    });

    test('payTransaction posts the otp to processingOTP', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://test.zaincash.iq/transaction/processingOTP?type=MERCHANT_PAYMENT');
        final body = Uri.splitQueryString(request.body);
        expect(body['otp'], '1111');
        return http.Response(
          jsonEncode({'success': 1, 'msg': 'succesful_transaction'}),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final result = await service.payTransaction(
        transactionId: 'tx-1',
        phoneNumber: '9647802999569',
        pin: '1234',
        otp: '1111',
      );

      expect(result.success, isTrue);
      expect(result.message, 'succesful_transaction');
    });

    test('failure responses map to success=false with message', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': 0, 'error': 'wrong pin'}),
          200,
        );
      });

      final service = ZainCashService(config, client: client);
      final result = await service.processingTransaction(
        transactionId: 'tx-1',
        phoneNumber: '9647802999569',
        pin: '1234',
      );

      expect(result.success, isFalse);
      expect(result.message, 'wrong pin');
    });

    test('cancelTransaction posts id and MERCHANT_PAYMENT type', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://test.zaincash.iq/transaction/cancel');
        final body = Uri.splitQueryString(request.body);
        expect(body, {'id': 'tx-1', 'type': 'MERCHANT_PAYMENT'});
        return http.Response(jsonEncode({'success': 0, 'msg': 'ok'}), 200);
      });

      final service = ZainCashService(config, client: client);
      final result = await service.cancelTransaction('tx-1');
      expect(result.message, 'ok');
    });
  });

  group('redirect decoding (WebView flow)', () {
    final service = ZainCashService(config);

    test('decodes a success token into a result', () {
      final token = JWT({
        'status': 'success',
        'orderid': 'order-123',
        'id': 'tx-789',
        'msg': 'Transaction success',
      }).sign(SecretKey(config.secret));

      final result = service.decodeRedirect(token);

      expect(result.status, ZainCashStatus.success);
      expect(result.orderId, 'order-123');
      expect(result.transactionId, 'tx-789');
    });

    test('throws on a token signed with a different secret', () {
      final token = JWT({'status': 'success'}).sign(SecretKey('wrong-secret'));
      expect(
        () => service.decodeRedirect(token),
        throwsA(isA<ZainCashException>()),
      );
    });

    test('returns null when redirect url has no token', () {
      expect(
          service.tryDecodeRedirectUrl('https://example.com/return'), isNull);
    });
  });
}
