## 0.0.1

* ZainCash Payment Gateway API v2 (docs.zaincash.iq): OAuth2 client
  credentials with token caching, transaction init, inquiry, reversal
  (refund), and callback JWT decoding.
* Ready-to-use `ZainCashPaymentPage` WebView screen and
  `ZainCashPayment.start` helper returning a typed `ZainCashPaymentResult`.
* UAT (test) and production environment support.
* Legacy API (`api.zaincash.iq`, merchantId + JWT secret) preserved under
  `package:zaincash_payment/zaincash_payment_legacy.dart`.
