import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class LocalDashboardServer {
  final String assetsPrefix;
  HttpServer? _server;

  LocalDashboardServer({this.assetsPrefix = 'assets/zashboard/'});

  Future<Uri> start() async {
    if (_server != null) {
      return Uri.parse('http://127.0.0.1:${_server!.port}/');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handleRequest, onError: (_) {});
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
    try {
      final assetKey = await _resolveAssetKey(path);
      final data = await rootBundle.load(assetKey);
      final bytes = data.buffer.asUint8List();
      request.response.headers.contentType = _contentTypeFor(assetKey);
      request.response.add(bytes);
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      await request.response.close();
    }
  }

  Future<String> _resolveAssetKey(String path) async {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final candidates = <String>[
      '$assetsPrefix$normalized',
      '$assetsPrefix${normalized.replaceFirst('assets/', '')}',
      '$assetsPrefix${normalized.startsWith('assets/') ? normalized : 'assets/$normalized'}',
    ];
    for (final key in candidates) {
      try {
        await rootBundle.load(key);
        return key;
      } catch (_) {
        // try next
      }
    }
    if (_isSpaRoute(normalized)) {
      return '${assetsPrefix}index.html';
    }
    throw const FileSystemException('Asset not found');
  }

  bool _isSpaRoute(String normalized) {
    if (!normalized.contains('.')) {
      return true;
    }
    return false;
  }


  ContentType _contentTypeFor(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.js')) return ContentType('application', 'javascript');
    if (path.endsWith('.css')) return ContentType('text', 'css');
    if (path.endsWith('.json')) return ContentType('application', 'json');
    if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (path.endsWith('.png')) return ContentType('image', 'png');
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return ContentType('image', 'jpeg');
    }
    if (path.endsWith('.webp')) return ContentType('image', 'webp');
    if (path.endsWith('.ico')) return ContentType('image', 'vnd.microsoft.icon');
    if (path.endsWith('.woff')) return ContentType('font', 'woff');
    if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
    return ContentType.binary;
  }
}
