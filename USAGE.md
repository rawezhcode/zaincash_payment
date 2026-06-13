# Using `zaincash_payment` in your app

This guide shows how to add ZainCash payments to a Flutter app step by step.

## 1. Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  zaincash_payment:
    path: ../zaincash_payment   # or a version once published, e.g. ^0.0.1
```

Then fetch packages:

```bash
flutter pub get
```

## 2. Platform setup

`webview_flutter` is bundled and works out of the box, but make sure:

### Android

- Minimum SDK 19+ (default for modern Flutter).
- Internet permission is needed for release builds. Add to
  `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS

- No extra setup is required for HTTPS pages (ZainCash uses HTTPS).
- Minimum iOS deployment target 12.0+.

## 3. Get your merchant credentials

ZainCash provides these when you register a merchant account
(test credentials are available for development):

| Field        | Example                          |
| ------------ | -------------------------------- |
| `msisdn`     | `9647835077893` (wallet number)  |
| `merchantId` | `5ffacf6612b5777c6d44266f`       |
| `secret`     | `$2y$10$...` (long string)       |

## 4. Configure the gateway

```dart
import 'package:zaincash_payment/zaincash_payment.dart';

const config = ZainCashConfig(
  msisdn: '9647835077893',
  merchantId: '5ffacf6612b5777c6d44266f',
  secret: 'YOUR_ZAINCASH_SECRET',
  lang: ZainCashLang.english, // ar | en | ku
  isTest: true,               // false for production
);
```

> Use `isTest: true` while developing. Switch to `false` only with production
> credentials.

## 5. Start a payment

The simplest way is the `ZainCashPayment.start` helper. It pushes the payment
screen and returns a `ZainCashResult`.

```dart
import 'package:flutter/material.dart';
import 'package:zaincash_payment/zaincash_payment.dart';

class CheckoutButton extends StatelessWidget {
  const CheckoutButton({super.key});

  Future<void> _pay(BuildContext context) async {
    final transaction = ZainCashTransaction(
      amount: 1000,            // IQD, minimum 250
      serviceType: 'My Store',
      orderId: 'order-123',    // optional, echoed back in the result
      redirectUrl: 'https://example.com/zaincash/return',
    );

    final result = await ZainCashPayment.start(
      context,
      config: config,
      transaction: transaction,
      title: 'Pay with ZainCash',
    );

    if (!context.mounted) return;

    switch (result.status) {
      case ZainCashStatus.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paid! Tx: ${result.transactionId}')),
        );
        break;
      case ZainCashStatus.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${result.msg}')),
        );
        break;
      case ZainCashStatus.pending:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment is pending')),
        );
        break;
      case ZainCashStatus.unknown:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown payment status')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _pay(context),
      child: const Text('Pay with ZainCash'),
    );
  }
}
```

## 6. Understand the result

`ZainCashResult` contains:

| Field           | Description                                       |
| --------------- | ------------------------------------------------- |
| `status`        | `success`, `failed`, `pending`, or `unknown`      |
| `isSuccess`     | `true` only when `status == success`              |
| `transactionId` | The ZainCash transaction id                       |
| `orderId`       | Your `orderId`, echoed back                       |
| `msg`           | Human readable message                            |
| `raw`           | Full decoded JWT payload (`Map<String, dynamic>`) |

If the user backs out before finishing, the result is
`ZainCashStatus.failed` with `msg == 'cancelled'`.

## 7. Embedding the screen directly (optional)

Instead of the helper, you can place `ZainCashPaymentPage` on your own route and
customize the app bar, loading, and error widgets:

```dart
final result = await Navigator.of(context).push<ZainCashResult>(
  MaterialPageRoute(
    builder: (_) => ZainCashPaymentPage(
      config: config,
      transaction: transaction,
      title: 'Checkout',
      loadingBuilder: (_) => const Center(child: Text('Preparing...')),
      errorBuilder: (_, error) => Center(child: Text('Error: $error')),
    ),
  ),
);
```

## 8. Building your own UI (advanced)

If you do not want the bundled WebView screen, use `ZainCashService` and wire up
your own WebView:

```dart
final service = ZainCashService(config);

// 1. Initialize and get the transaction id.
final transactionId = await service.initTransaction(transaction);

// 2. Load this URL in your WebView.
final payUrl = service.payUrl(transactionId);

// 3. When your WebView navigates to a URL containing ?token=...
final result = service.tryDecodeRedirectUrl(currentUrl); // null if no token

// 4. Release the HTTP client when done.
service.dispose();
```

## 9. Error handling

API calls throw `ZainCashException` with a `type`:

```dart
try {
  final id = await service.initTransaction(transaction);
} on ZainCashException catch (e) {
  switch (e.type) {
    case ZainCashErrorType.network:
      // could not reach ZainCash
      break;
    case ZainCashErrorType.initFailure:
      // ZainCash rejected the request (bad amount, credentials, etc.)
      break;
    case ZainCashErrorType.tokenDecode:
      // returned token could not be verified
      break;
  }
}
```

## Security reminder

This package signs the JWT on the device, so your merchant `secret` ends up in
the app binary. For production-sensitive apps, generate the token and
transaction id on your own backend and pass them to the client instead.
