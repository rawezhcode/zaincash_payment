import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models/zaincash_config.dart';
import 'models/zaincash_result.dart';
import 'models/zaincash_transaction.dart';
import '../zaincash_exception.dart';
import 'zaincash_service.dart';

/// A full-screen WebView that drives a ZainCash payment to completion.
///
/// It initializes the transaction, loads the hosted payment page, intercepts
/// the redirect back to [ZainCashTransaction.redirectUrl], decodes the result
/// token and pops with a [ZainCashResult].
class ZainCashPaymentPage extends StatefulWidget {
  const ZainCashPaymentPage({
    super.key,
    required this.config,
    required this.transaction,
    this.title = 'ZainCash',
    this.appBar,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final ZainCashConfig config;
  final ZainCashTransaction transaction;

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
      final redirectUrl = widget.transaction.redirectUrl;
      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw const ZainCashException(
          ZainCashErrorType.validation,
          'A redirectUrl is required for the hosted payment page flow.',
        );
      }
      final details = await _service.createTransaction(widget.transaction);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: _handleNavigation,
          ),
        )
        ..loadRequest(_service.payUrl(details.id));
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final redirectUrl = widget.transaction.redirectUrl ?? '';
    final isRedirect = (redirectUrl.isNotEmpty &&
            request.url.startsWith(redirectUrl)) ||
        Uri.tryParse(request.url)?.queryParameters.containsKey('token') == true;

    if (isRedirect) {
      try {
        final result = _service.tryDecodeRedirectUrl(request.url);
        if (result != null) {
          _finish(result);
          return NavigationDecision.prevent;
        }
      } on ZainCashException catch (e) {
        if (mounted) setState(() => _error = e);
        return NavigationDecision.prevent;
      }
    }
    return NavigationDecision.navigate;
  }

  void _finish(ZainCashResult result) {
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
          Navigator.of(context).pop(ZainCashResult.cancelled());
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
    final message =
        error is ZainCashException ? (error as ZainCashException).message : '$error';
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
