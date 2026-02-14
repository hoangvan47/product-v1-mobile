import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const miniAppUrl = String.fromEnvironment(
  'MINI_APP_URL',
  defaultValue: 'https://mobile-connection-817931.framer.app/',
);

void main() {
  runApp(const MiniAppHost());
}

class MiniAppHost extends StatelessWidget {
  const MiniAppHost({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product V1 Mini App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A0A0A)),
        useMaterial3: true,
      ),
      home: const MiniAppWebViewPage(),
    );
  }
}

class MiniAppWebViewPage extends StatefulWidget {
  const MiniAppWebViewPage({super.key});

  @override
  State<MiniAppWebViewPage> createState() => _MiniAppWebViewPageState();
}

class _MiniAppWebViewPageState extends State<MiniAppWebViewPage> {
  late final WebViewController _controller;
  String _lastWebMessage = 'No message yet';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            _sendToWeb(
              type: 'flutter_ready',
              payload: {
                'platform': defaultTargetPlatform.name,
                'miniApp': 'product_v1_mobile',
              },
            );
          },
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          setState(() {
            _lastWebMessage = message.message;
          });
        },
      )
      ..loadRequest(Uri.parse(miniAppUrl));
  }

  Future<void> _sendToWeb({
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    final data = jsonEncode({
      'source': 'flutter',
      'type': type,
      'payload': payload ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    });

    final escapedData = jsonEncode(data);
    await _controller.runJavaScript(
      'window.receiveFromFlutter && window.receiveFromFlutter($escapedData);',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini App Host'),
        actions: [
          IconButton(
            tooltip: 'Send ping to web',
            onPressed: () {
              _sendToWeb(
                type: 'ping_from_flutter',
                payload: {'message': 'Hello from Flutter mini app'},
              );
            },
            icon: const Icon(Icons.send_outlined),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
          Container(
            width: double.infinity,
            color: const Color(0xFFF2F2F2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              'Web -> Flutter: $_lastWebMessage',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
