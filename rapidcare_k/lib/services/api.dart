// lib/services/api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Chrome: 127.0.0.1. Android emulator: 10.0.2.2.
/// Physical phone: pass API_BASE as a private Wi-Fi HTTP URL for development or a public HTTPS URL for a release build.
const String _override = String.fromEnvironment('API_BASE');
String? _apiToken;
const LatLng kRapidCareCoverageCenter = LatLng(19.17, 72.85);

void setApiToken(String? token) {
  _apiToken = token?.trim().isEmpty == true ? null : token?.trim();
}

String get kApiBase {
  if (_override.trim().isNotEmpty) return _override.trim().replaceFirst(RegExp(r'/+$'), '');
  if (kIsWeb) {
    final host = Uri.base.host.isEmpty ? '127.0.0.1' : Uri.base.host;
    final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
    return '$scheme://$host:5000';
  }
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000';
  return 'http://127.0.0.1:5000';
}

Future<dynamic> api(String path, {String method = 'GET', Map<String, dynamic>? body, Map<String, String>? headers}) async {
  final u = Uri.parse('$kApiBase${path.startsWith('/') ? path : '/$path'}');
  final h = {'Content-Type': 'application/json', ...?headers};
  final isPublicCredentialRoute = path.endsWith('/driver/login') ||
      path.endsWith('/driver/register') ||
      path == '/api/patient/login' || path == '/api/patient/register' ||
      path == '/api/app/emergency';
  if (!isPublicCredentialRoute && _apiToken != null && !h.containsKey('Authorization')) {
    h['Authorization'] = 'Bearer $_apiToken';
  }
  final b = body == null ? null : jsonEncode(body);
  http.Response r;
  try {
    Future<http.Response> send() => method == 'GET'
        ? http.get(u, headers: h)
        : method == 'PATCH'
            ? http.patch(u, headers: h, body: b)
            : http.post(u, headers: h, body: b);
    try {
      r = await send().timeout(const Duration(seconds: 75));
    } on Exception {
      if (method != 'GET') rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      r = await send().timeout(const Duration(seconds: 15));
    }
  } catch (e) {
    throw Exception('Cannot reach RapidCare at $kApiBase. Check network access and the configured API_BASE. The public demo service may take about a minute to wake after inactivity. ($e)');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(r.body);
  } catch (_) {
    decoded = r.body;
  }
  if (r.statusCode >= 400) {
    final message = decoded is Map ? decoded['message'] : null;
    throw Exception(message ?? 'RapidCare returned HTTP ${r.statusCode} at $kApiBase');
  }
  return decoded;
}

/// Reads {"lat":..,"lng":..} from any map, or null.
LatLng? latLngOf(dynamic o) {
  if (o is! Map) return null;
  final la = (o['lat'] as num?)?.toDouble(), ln = (o['lng'] as num?)?.toDouble();
  return (la == null || ln == null) ? null : LatLng(la, ln);
}

class RoadRoute {
  final List<LatLng> points;
  final double km, min;
  final String next; // next turn, e.g. "In 200 m: turn right onto SV Road"
  RoadRoute(this.points, this.km, this.min, this.next);
}

/// Real driving route + next manoeuvre (OSRM public server, no API key).
Future<RoadRoute?> roadRoute(LatLng a, LatLng b) async {
  try {
    final u = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
        '?overview=full&geometries=geojson&steps=true');
    final r = await http.get(u).timeout(const Duration(seconds: 8));
    final route = jsonDecode(r.body)['routes'][0];
    final steps = route['legs'][0]['steps'] as List;
    final s = steps.length > 1 ? steps[1] : steps[0];
    final name = (s['name'] ?? '').toString();
    final text = 'In ${(steps[0]['distance'] as num).round()} m: ${s['maneuver']['type']} '
        '${s['maneuver']['modifier'] ?? ''}${name.isEmpty ? '' : ' onto $name'}';
    return RoadRoute(
      (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList(),
      (route['distance'] as num) / 1000,
      (route['duration'] as num) / 60,
      text,
    );
  } catch (_) {
    return null;
  }
}
