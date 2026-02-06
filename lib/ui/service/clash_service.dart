import 'dart:convert';
import 'dart:io';

class ClashResponse {
  final int statusCode;
  final String body;

  const ClashResponse(this.statusCode, this.body);

  bool get ok => statusCode >= 200 && statusCode < 300;
}

class ClashJsonResponse {
  final int statusCode;
  final String body;
  final Map<String, dynamic> data;

  const ClashJsonResponse(this.statusCode, this.body, this.data);

  bool get ok => statusCode >= 200 && statusCode < 300;
}

class ClashService {
  final String baseUrl;
  final String token;

  const ClashService({required this.baseUrl, required this.token});

  Future<ClashJsonResponse> getConfigs() => getJson('/configs');

  Future<ClashJsonResponse> getProvidersProxies() =>
      getJson('/providers/proxies');

  Future<ClashJsonResponse> getProxies() => getJson('/proxies');

  Future<ClashResponse> patchConfigsMode(String modeValue) async {
    return _sendJson('PATCH', '/configs', {'mode': modeValue});
  }

  Future<ClashResponse> putProxy(String group, String name) async {
    return _sendJson('PUT', '/proxies/$group', {'name': name});
  }


  Future<ClashJsonResponse> getJson(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          return ClashJsonResponse(response.statusCode, body, data);
        }
        return ClashJsonResponse(response.statusCode, body, {});
      }
      return ClashJsonResponse(response.statusCode, body, {});
    } finally {
      client.close();
    }
  }

  Future<ClashResponse> _sendJson(
    String method,
    String path,
    Map<String, dynamic>? payload,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (payload != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(payload));
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return ClashResponse(response.statusCode, body);
    } finally {
      client.close();
    }
  }
}
