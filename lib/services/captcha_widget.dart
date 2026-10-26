import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:guin_app/config/supabase_config.dart';

/// reCAPTCHA v2 widget rendered inside an in-app WebView.
///
/// Loads the captcha page from the `captcha` Supabase Edge Function, which
/// serves the reCAPTCHA widget and verifies the token server-side. On
/// success it calls [onSolved] with the token.
class CaptchaWidget extends StatefulWidget {
  const CaptchaWidget({
    super.key,
    required this.onSolved,
    this.height = 220,
  });

  /// Called with the reCAPTCHA token on success.
  final ValueChanged<String> onSolved;

  /// Height of the WebView in logical pixels.
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
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..addJavaScriptChannel(
        'flutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
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
      )
      ..loadRequest(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/captcha'),
      );
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