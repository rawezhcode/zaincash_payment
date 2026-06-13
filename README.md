<img width="1448" height="1086" alt="ChatGPT Image Jun 13, 2026, 05_26_07 PM" src="https://github.com/user-attachments/assets/5ab89186-265d-4bb1-9ea5-532f8da9b467" />


# zaincash_payment

A Flutter merchant gateway for the **ZainCash Payment Gateway API v2**
([docs.zaincash.iq](https://docs.zaincash.iq)). Supports OAuth2
authentication, transaction creation, a ready-to-use WebView payment screen,
status inquiry, callback token decoding, and reversals (refunds).

> Old merchant account (merchantId + JWT secret on `api.zaincash.iq`)?
> Import `package:zaincash_payment/zaincash_payment_legacy.dart` instead -
> the previous implementation is kept there.

## Features

- OAuth2 `client_credentials` authentication with token caching.
- `createTransaction` - create a payment, get the hosted page `redirectUrl`.
- `ZainCashPaymentPage` - WebView screen that completes the whole flow and
  returns a typed `ZainCashPaymentResult`.
- `checkTransaction` - transaction inquiry (status, fees, timestamps).
- `reverseTransaction` - refund a successful transaction.
- Callback JWT decoding with signature verification.
- UAT (test) and production environments.

## Install

```yaml
dependencies:
  zaincash_payment: ^0.0.1
```

## Configure

ZainCash provides a **Client ID**, **Client Secret**, and your production
API link during onboarding.

```dart
import 'package:zaincash_payment/zaincash_payment.dart';

const config = ZainCashConfig(
  clientId: 'YOUR_CLIENT_ID',
  clientSecret: 'YOUR_CLIENT_SECRET',
  apiKey: 'YOUR_API_KEY',                          // optional, for JWT verification
  lang: ZainCashLang.english,                      // ar | en | ku
  isTest: true,                                    // UAT environment
  productionBaseUrl: 'https://pg-api.zaincash.iq', // from onboarding
);
```

UAT test credentials (from the official docs):

```dart
const testConfig = ZainCashConfig(
  clientId: '758055f4a8044779a35f6ceb69f858b3',
  clientSecret: 'bibLCGTxVAig5To3OLLKPJQMlRR7Pefp',
  isTest: true,
);
// Test customers: 9647802999569 / PIN 1111 / OTP 111111
```

## Pay with the built-in WebView screen

```dart
final result = await ZainCashPayment.start(
  context,
  config: config,
  request: const ZainCashPaymentRequest(
    amount: 500,                                  // IQD
    orderId: 'order-123',
    serviceType: 'Delivery',
    successUrl: 'https://example.com/zaincash/success',
    failureUrl: 'https://example.com/zaincash/failure',
  ),
);

if (result.isSuccess) {
  // result.transactionId, result.event?.customerMsisdn
} else {
  // result.message (== 'cancelled' when the user backed out)
}
```

If `result.event?.verified == false`, confirm with `checkTransaction`
before fulfilling the order.

## Direct API usage

```dart
final service = ZainCashService(config);

// 1. Create the payment.
final session = await service.createTransaction(const ZainCashPaymentRequest(
  amount: 500,
  orderId: 'order-123',
  serviceType: 'Delivery',
  successUrl: 'https://example.com/success',
  failureUrl: 'https://example.com/failure',
));

// 2. Redirect the customer to session.redirectUrl (use it as-is).

// 3. After the redirect back, decode the token.
final event = service.tryDecodeRedirectUrl(returnedUrl);

// 4. Confirm the final status.
final details = await service.checkTransaction(session.transactionId);
// details.status: success | failed | pending | otpSent |
//                 customerAuthenticationRequired | expired | refunded

// 5. Refund if needed (requires the reverse:write scope).
final reversal = await service.reverseTransaction(
  transactionId: session.transactionId,
  reason: 'customer request',
);

service.dispose();
```

## Error handling

API and validation errors throw `ZainCashException` with a `type` of
`validation`, `auth`, `network`, `apiFailure`, or `tokenDecode`.

## Security note

This package authenticates **on the device**, which embeds your
`clientSecret` in the app binary. ZainCash recommends keeping secrets
server-side: for sensitive deployments, run the OAuth + init steps on your
backend and pass `redirectUrl` to the app.

## License

See [LICENSE](LICENSE).
