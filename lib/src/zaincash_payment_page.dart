import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models/zaincash_config.dart';
import 'models/zaincash_payment_request.dart';
import 'models/zaincash_payment_result.dart';
import 'zaincash_exception.dart';
import 'zaincash_service.dart';

/// A full-screen WebView that drives a ZainCash v2 payment to completion.
///
/// It creates the transaction, loads the hosted payment page (the
/// `redirectUrl` returned by ZainCash), intercepts the redirect back to your
/// `successUrl`/`failureUrl`, decodes the callback token, and pops with a
/// [ZainCashPaymentResult].
class ZainCashPaymentPage extends StatefulWidget {
  const ZainCashPaymentPage({
    super.key,
    required this.config,
    required this.request,
    this.title = 'ZainCash',
    this.appBar,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final ZainCashConfig config;
  final ZainCashPaymentRequest request;

  /// Title shown in the default app bar.
  final String title;

  /// Optional custom app bar replacing the default one.
  final PreferredSizeWidget? appBar;

  /// Optional builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Optional builder for the error state. Receives the thrown exception.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<ZainCashPaymentPage> createState() => _ZainCashPaymentPageState();
}

class _ZainCashPaymentPageState extends State<ZainCashPaymentPage> {
  late final ZainCashService _service;
  WebViewController? _controller;
  Object? _error;
  bool _completed = false;
  String? _transactionId;

  @override
  void initState() {
    super.initState();
    _service = ZainCashService(widget.config);
    _start();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final session = await _service.createTransaction(widget.request);
      _transactionId = session.transactionId;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: _handleNavigation,
          ),
        )
        ..loadRequest(Uri.parse(session.redirectUrl));
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;
    final isCallback = url.startsWith(widget.request.successUrl) ||
        url.startsWith(widget.request.failureUrl);

    if (isCallback) {
      try {
        final event = _service.tryDecodeRedirectUrl(url);
        if (event != null) {
          _finish(ZainCashPaymentResult.fromEvent(event));
        } else {
          // Redirected back without a token: treat as cancelled/failed.
          _finish(
              ZainCashPaymentResult.cancelled(transactionId: _transactionId));
        }
      } on ZainCashException catch (e) {
        if (mounted) setState(() => _error = e);
      }
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _finish(ZainCashPaymentResult result) {
    if (_completed) return;
    _completed = true;
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_completed) {
          _completed = true;
          Navigator.of(context).pop(
              ZainCashPaymentResult.cancelled(transactionId: _transactionId));
        }
      },
      child: Scaffold(
        appBar: widget.appBar ?? AppBar(title: Text(widget.title)),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          _DefaultError(error: _error!);
    }
    if (_controller == null) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: _controller!);
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ZainCashException
        ? (error as ZainCashException).message
        : '$error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
