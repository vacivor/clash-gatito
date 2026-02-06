import 'dart:convert';
import 'dart:io';

class DiagnosticsService {
  Future<Map<String, String>> fetchIpResults({
    Duration timeout = const Duration(seconds: 5),
    String? upaiYunEndpoint,
  }) async {
    final results = <String, String>{};
    results['IPIP.NET'] = await _fetchIpip(timeout);
    results['IPIFY'] = await _fetchIpify(timeout);
    results['IP.SB'] = await _fetchIpSb(timeout);
    if (upaiYunEndpoint != null && upaiYunEndpoint.isNotEmpty) {
      results['UpaiYun'] = await _fetchUpaiYun(upaiYunEndpoint, timeout);
    } else {
      results['UpaiYun'] = 'Not configured';
    }
    return results;
  }

  Future<Map<String, Duration?>> testLatencies(
    List<Uri> targets, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final results = <String, Duration?>{};
    for (final target in targets) {
      results[target.host] = await _measureLatency(target, timeout);
    }
    return results;
  }

  Future<String> _fetchIpip(Duration timeout) async {
    // IPIP.NET: http://myip.ipip.net returns plain text
    return _fetchPlain('http://myip.ipip.net', timeout);
  }

  Future<String> _fetchIpify(Duration timeout) async {
    final body = await _fetchPlain(
      'https://api.ipify.org?format=json',
      timeout,
    );
    try {
      final data = jsonDecode(body);
      if (data is Map && data['ip'] is String) {
        return data['ip'] as String;
      }
    } catch (_) {}
    return body;
  }

  Future<String> _fetchIpSb(Duration timeout) async {
    return _fetchPlain('https://api.ip.sb/ip', timeout);
  }

  Future<String> _fetchUpaiYun(String url, Duration timeout) async {
    final body = await _fetchPlain(url, timeout);
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final remoteAddr = data['remote_addr']?.toString();
        final location = data['remote_addr_location'];
        if (remoteAddr != null && location is Map) {
          final country = location['country']?.toString();
          final province = location['province']?.toString();
          final city = location['city']?.toString();
          final isp = location['isp']?.toString();
          final parts = [
            if (country != null && country.isNotEmpty) country,
            if (province != null && province.isNotEmpty) province,
            if (city != null && city.isNotEmpty) city,
            if (isp != null && isp.isNotEmpty) isp,
          ];
          final locationText = parts.join(' ');
          if (locationText.isNotEmpty) {
            return '$remoteAddr · $locationText';
          }
          return remoteAddr;
        }
      }
    } catch (_) {}
    return body;
  }

  Future<String> _fetchPlain(String url, Duration timeout) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      return body.trim();
    } catch (e) {
      return 'Error: $e';
    } finally {
      client.close();
    }
  }

  Future<Duration?> _measureLatency(Uri url, Duration timeout) async {
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    try {
      final request = await client.openUrl('HEAD', url);
      final response = await request.close().timeout(timeout);
      await response.drain();
      stopwatch.stop();
      return stopwatch.elapsed;
    } on HttpException {
      // Some servers reject HEAD; try GET
      try {
        final request = await client.getUrl(url);
        final response = await request.close().timeout(timeout);
        await response.drain();
        stopwatch.stop();
        return stopwatch.elapsed;
      } catch (_) {
        stopwatch.stop();
        return null;
      }
    } catch (_) {
      stopwatch.stop();
      return null;
    } finally {
      client.close();
    }
  }
}
