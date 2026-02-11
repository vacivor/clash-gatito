import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../local_dashboard_server.dart';

class ZashboardPage extends StatefulWidget {
  final String host;
  final int port;
  final String secret;
  final bool useLocalServer;

  const ZashboardPage({
    super.key,
    required this.host,
    required this.port,
    required this.secret,
    this.useLocalServer = true,
  });

  @override
  State<ZashboardPage> createState() => _ZashboardPageState();
}

class _ZashboardPageState extends State<ZashboardPage> {
  late final WebViewController _controller;
  final LocalDashboardServer _server = LocalDashboardServer();
  bool _isLoading = true;
  String? _currentUrl;
  bool _hasLoadedInitial = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final url = request.url;
            if (!_hasLoadedInitial) {
              _hasLoadedInitial = true;
              return NavigationDecision.navigate;
            }
            if (url.isNotEmpty) {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
        ),
      );
    // Start the server asynchronously to avoid blocking first frame.
    Future.microtask(_loadInitialUrl);
  }

  Future<void> _loadInitialUrl() async {
    if (widget.useLocalServer) {
      final uri = await _server.start();
      _currentUrl = uri.toString();
      debugPrint('Zashboard URL: $_currentUrl');
      await _controller.loadRequest(uri);
      return;
    }
    _currentUrl = widget.buildSetupUrl().toString();
    debugPrint('Zashboard URL: $_currentUrl');
    await _controller.loadRequest(Uri.parse(_currentUrl!));
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

extension ZDashboardSetup on ZashboardPage {
  Uri buildSetupUrl() {
    final host = this.host;
    final port = this.port;
    final secret = this.secret;
    return Uri.parse(
      'http://$host:$port/ui/zashboard/#/setup?hostname=$host&port=$port&secret=$secret',
    );
  }
}
