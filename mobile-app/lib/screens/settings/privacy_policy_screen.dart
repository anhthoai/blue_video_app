import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  static final Uri privacyPolicyUri =
      Uri.parse('https://onlybl.com/privacy-policy.html');

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _hasError = false;
              _loadingProgress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _loadingProgress = 100;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(PrivacyPolicyScreen.privacyPolicyUri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicy),
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.openPrivacyPolicyFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _loadingProgress = 0;
                        });
                        _controller.loadRequest(PrivacyPolicyScreen.privacyPolicyUri);
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (!_hasError && _loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100),
        ],
      ),
    );
  }
}