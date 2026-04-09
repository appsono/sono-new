import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Extract user token from localStorage
///
/// Open discord.com/login. Once the user logs in and lands on /app,
/// evaluate JS to grab the token from localStorage
class DiscordLoginPage extends StatefulWidget {
  const DiscordLoginPage({super.key});

  @override
  State<DiscordLoginPage> createState() => _DiscordLoginPageState();
}

class _DiscordLoginPageState extends State<DiscordLoginPage> {
  bool _loading = true;
  bool _extracted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://discord.com/login'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              //clear cache to ensure fresh login
              clearCache: false,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/146.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              //inject JS on page start to preserve token
              //discords JS tries to remove the token form localStorage
              //on certain navigations. hook removeItem to prevent that
              controller.addUserScript(
                userScript: UserScript(
                  source: '''
                    (function() {
                      window.__SONO_LS = localStorage;
                      var origRemove = localStorage.removeItem.bind(localStorage);
                      localStorage.removeItem = function(key) {
                        if (key === 'token') return true;
                        return origRemove(key);
                      };
                    })();
                  ''',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              );
            },
            onLoadStop: (controller, url) async {
              setState(() => _loading = false);
              await _tryExtractToken(controller, url);
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) async {
              await _tryExtractToken(controller, url);
            },
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<void> _tryExtractToken(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final urlStr = url?.toString() ?? '';
    if (!urlStr.contains('discord.com/app') &&
        !urlStr.contains('discord.com/channels')) {
      return;
    }
    if (_extracted) return;
    _extracted = true;

    final navigator = Navigator.of(context);

    //small delay to let discord JS set token
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await controller.evaluateJavascript(
      source: '(function() { return window.__SONO_LS.getItem("token"); })()',
    );

    if (result != null && mounted) {
      //result comes back as a quoted string like '"abc..."'
      String token = result.toString();
      //strip surrounding quotes if present
      if (token.startsWith('"') && token.endsWith('"')) {
        token = token.substring(1, token.length - 1);
      }

      if (token.length > 50) {
        navigator.pop(token);
      } else {
        _showError('Could not extract token (length: ${token.length})');
        _extracted = false;
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
