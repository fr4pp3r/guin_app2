import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// reCAPTCHA v2 widget rendered inside an in-app WebView.
///
/// Loads the bundled `assets/captcha.html` directly. The Supabase edge
/// function injects a `default-src 'none'; sandbox` CSP on GET responses
/// that blocks all script execution, so the asset is loaded locally instead.
/// On success it calls [onSolved] with the token.
///
/// Default height is 380dp - enough for the checkbox and image-select challenge.
class CaptchaWidget extends StatefulWidget {
  const CaptchaWidget({super.key, required this.onSolved, this.height = 500});

  /// Called with the reCAPTCHA token on success.
  final ValueChanged<String> onSolved;

  /// Height of the WebView in logical pixels. The reCAPTCHA v2 checkbox takes
  /// about 300-350dp; 380dp provides a comfortable buffer.
  final double height;

  @override
  State<CaptchaWidget> createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            debugPrint('captcha widget nav: ${request.url}');
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('captcha widget resource error: ${error.description}');
          },
          onPageFinished: (url) {
            debugPrint('captcha widget page finished: $url');
            setState(() => _loading = false);
          },
        ),
      )
      ..addJavaScriptChannel(
        'flutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('captcha widget jsChannel: ${message.message}');
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            if (data['type'] == 'captcha_solved' &&
                (data['token'] as String?)?.isNotEmpty == true) {
              widget.onSolved(data['token'] as String);
            }
          } catch (_) {
            // Malformed message — ignore.
          }
        },
      );
    _loadCaptchaPage();
  }

  Future<void> _loadCaptchaPage() async {
    try {
      final html = await rootBundle.loadString('assets/captcha.html');
      await _controller.loadHtmlString(
        html,
        baseUrl: 'https://isfzfpowtwcapjshtemd.supabase.co/',
      );
    } catch (e) {
      debugPrint('Error loading captcha asset: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: WebViewWidget(controller: _controller),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
