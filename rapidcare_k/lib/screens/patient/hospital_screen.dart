import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import 'facility_reviews.dart';

const Color _teal = Color(0xFF00796B);
const Color _tealDark = Color(0xFF004D40);

class Hospital {
  final int id;
  final String name, location, phone, edStatus;
  final LatLng? pos;
  final double? rating, distanceKm;
  final List<String> recommendationReasons;
  final int reviewCount;
  final int? etaMin;
  final int beds, icu, score;
  final int? capabilityMatches;
  final List<String> specialists, facilities, units;

  Hospital({
    required this.id,
    required this.name,
    required this.location,
    required this.phone,
    required this.edStatus,
    required this.pos,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.recommendationReasons,
    required this.etaMin,
    required this.beds,
    required this.icu,
    required this.score,
    required this.capabilityMatches,
    required this.specialists,
    required this.facilities,
    required this.units,
  });

  factory Hospital.fromJson(Map<String, dynamic> j) {
    List<String> on(dynamic m) =>
        m is Map ? m.entries.where((e) => e.value == true).map((e) => e.key.toString()).toList() : [];
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    return Hospital(
      id: j['id'],
      name: j['name'] ?? '',
      location: j['location'] ?? '',
      phone: j['phone'] ?? '',
      edStatus: j['ed_status'] ?? '',
      pos: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      rating: (j['rating'] as num?)?.toDouble(),
      reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
      recommendationReasons: (j['recommendation_reasons'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      etaMin: j['eta_min'],
      beds: j['available_beds'] ?? 0,
      icu: j['icu_beds'] ?? 0,
      score: j['score'] ?? 0,
      capabilityMatches: (j['capability_matches'] as num?)?.toInt(),
      specialists: on(j['specialists']),
      facilities: on(j['facilities']),
      units: on(j['units']),
    );
  }

  bool get limited => edStatus.toUpperCase().contains('LIMITED');
}

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  static const _types = ['Any', 'Cardiac', 'Trauma', 'Burn', 'Accident', 'Pregnancy'];
  final MapController _map = MapController();
  bool _mapReady = false;

  LatLng _user = kRapidCareCoverageCenter;
  bool _gps = false;
  double? _gpsAccuracy;

  List<Hospital> _all = [];
  Hospital? _sel;
  bool _loading = true;
  String? _error;

  String _type = 'Any', _view = 'Map & List', _q = '';
  int _loadGeneration = 0;
  String _loadedType = 'other';
  bool _pendingMapFit = true;

  List<LatLng> _route = [];
  double? _routeKm, _routeMin;

  Timer? _timer;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final locationRequest = _locate();
    await _load();
    if (!mounted) return;
    // Beds / ICU / ED status are edited in the hospital portal, so refresh regularly.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _locate(requestPermission: false);
      await _load(silent: true);
    });
    final foundLocation = await locationRequest;
    if (foundLocation && mounted) {
      await _load(silent: true, selectTop: true, focusMap: true);
    }
  }

  Future<bool> _locate({bool requestPermission = true}) async {
    try {
      var alreadyHadFix = _gps;
      final pos = await getFreshLocation(
        requestPermission: requestPermission,
        onPosition: (fix) {
          if (!mounted) return;
          final point = LatLng(fix.latitude, fix.longitude);
          final firstFix = !alreadyHadFix;
          if (!firstFix && fix.accuracy >= (_gpsAccuracy ?? double.infinity)) return;
          setState(() {
            _user = point;
            _gps = true;
            _gpsAccuracy = fix.accuracy;
          });
          alreadyHadFix = true;
          if (firstFix && _mapReady) {
            try {
              _map.move(point, 14);
            } catch (_) {}
          }
          if (firstFix) {
            unawaited(_load(silent: true, selectTop: true, focusMap: true));
          }
        },
      );
      if (!mounted) return false;
      setState(() {
        _user = LatLng(pos.latitude, pos.longitude);
        _gps = true;
        _gpsAccuracy = pos.accuracy;
      });
      return true;
    } catch (_) {
      if (mounted) setState(() { _gps = false; _gpsAccuracy = null; _route = []; _routeKm = null; _routeMin = null; });
      return false;
    }
  }

  Future<void> _load({bool silent = false, bool selectTop = false, bool focusMap = false}) async {
    final generation = ++_loadGeneration;
    if (focusMap) _pendingMapFit = true;
    final requestedType = _type == 'Any' ? 'other' : _type.toLowerCase();
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final query = <String, String>{
        'type': requestedType,
      };
      if (_gps) { query['lat'] = '${_user.latitude}'; query['lng'] = '${_user.longitude}'; }
      final result = await api('/api/app/hospitals${Uri(queryParameters: query)}');
      final list = (result as List).map((e) => Hospital.fromJson(e)).toList();
      if (!mounted || generation != _loadGeneration || requestedType != (_type == 'Any' ? 'other' : _type.toLowerCase())) return;
      _loadedType = requestedType;
      list.sort((a, b) {
        final byFit = _matchCount(b, requestedType).compareTo(_matchCount(a, requestedType));
        if (byFit != 0) return byFit;
        final byDistance = (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);
        return byDistance != 0 ? byDistance : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      final selected = selectTop || _sel == null
          ? (list.isNotEmpty ? list.first : null)
          : list.where((h) => h.id == _sel?.id).firstOrNull ?? (list.isNotEmpty ? list.first : null);
      setState(() {
        _all = list;
        _sel = selected;
        _loading = false;
        _error = null;
      });
      if (_pendingMapFit) _focusRecommendations();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        if (!silent || _all.isEmpty) _error = 'Cannot reach the RapidCare server ($kApiBase). Check Flask and the app API address.';
      });
    }
  }

  int _matchCount(Hospital hospital, String type) {
    if (_loadedType == type && hospital.capabilityMatches != null) return hospital.capabilityMatches!;
    final needs = switch (type) {
      'cardiac' => ('Cardiologist', '24x7 Cath Lab'),
      'trauma' || 'accident' => ('Orthopaedic', 'Emergency Physician'),
      'burn' => ('Plastic & Burn Surgeon', 'burn_unit'),
      'pregnancy' => ('Obstetrician & Gynecologist', 'maternity_ot'),
      _ => ('Emergency Physician', 'CT / MRI'),
    };
    final specialist = hospital.specialists.contains(needs.$1);
    final service = switch (needs.$2) {
      'maternity_ot' || 'burn_unit' => hospital.units.contains(needs.$2),
      'Emergency Physician' => hospital.specialists.contains('Emergency Physician'),
      _ => hospital.facilities.contains(needs.$2),
    };
    return (specialist ? 1 : 0) + (service ? 1 : 0);
  }

  String _fitExplanation(Hospital hospital) {
    if (hospital.recommendationReasons.isNotEmpty) return hospital.recommendationReasons.first;
    final matches = _matchCount(hospital, _type == 'Any' ? 'other' : _type.toLowerCase());
    if (matches == 2) return 'Required specialist and service are listed';
    if (matches == 1) return 'One required capability is listed; the other is not recorded';
    return hospital.distanceKm == null
        ? 'No required capabilities are listed; ordered by directory data'
        : 'No required capabilities are listed; ordered by distance';
  }

  List<Hospital> get _visible {
    if (_q.isEmpty) return _all;
    final q = _q.toLowerCase();
    return _all.where((h) => h.name.toLowerCase().contains(q) || h.location.toLowerCase().contains(q)).toList();
  }

  void _fit(List<LatLng> pts) {
    if (!_mapReady || pts.length < 2) return;
    try {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(48)));
    } catch (_) {}
  }

  void _focusRecommendations() {
    if (!_mapReady || _all.isEmpty) {
      _pendingMapFit = true;
      return;
    }
    final type = _type == 'Any' ? 'other' : _type.toLowerCase();
    final located = _visible.where((h) => h.pos != null).toList();
    final complete = located.where((h) => _matchCount(h, type) == 2).take(4).toList();
    final partial = located.where((h) => _matchCount(h, type) == 1).take(4).toList();
    final targets = complete.isNotEmpty ? complete : (partial.isNotEmpty ? partial : located.take(4).toList());
    final points = <LatLng>[if (_gps) _user, ...targets.map((h) => h.pos!)];
    if (points.length > 1) {
      _fit(points);
    } else if (points.length == 1) {
      try { _map.move(points.first, 13); } catch (_) {}
    }
    _pendingMapFit = false;
  }

  /// Select a hospital and draw the real driving route (OSRM, no API key needed).
  Future<void> _select(Hospital h) async {
    setState(() {
      _sel = h;
      _route = [];
      _routeKm = null;
      _routeMin = null;
    });
    if (h.pos == null) return;
    if (!_gps) {
      if (_mapReady) _map.move(h.pos!, 14);
      return;
    }
    _fit([_user, h.pos!]);
    try {
      final u = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${_user.longitude},${_user.latitude};${h.pos!.longitude},${h.pos!.latitude}?overview=full&geometries=geojson');
      final r = await http.get(u).timeout(const Duration(seconds: 8));
      final route = json.decode(r.body)['routes'][0];
      final pts = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      if (!mounted || _sel?.id != h.id) return;
      setState(() {
        _route = pts;
        _routeKm = (route['distance'] as num) / 1000;
        _routeMin = (route['duration'] as num) / 60;
      });
      _fit(pts);
    } catch (_) {} // keep the straight-line estimate from the backend
  }

  Future<void> _navigate(Hospital h) async {
    if (h.pos == null) return;
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${h.pos!.latitude},${h.pos!.longitude}&travelmode=driving'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _call(Hospital h) async {
    bool ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: h.phone));
    } catch (_) {}
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: h.phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${h.phone} copied to clipboard')));
      }
    }
  }

  void _openFullScreenMap() {
    final c = MapController();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: _tealDark,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Nearby hospitals', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: Stack(children: [
          _buildMap(c, full: true, onPick: () => Navigator.pop(ctx)),
          Positioned(left: 12, top: 12, child: _mapLegend()),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'relocate_hospital_full_btn',
              backgroundColor: _tealDark,
              onPressed: () => c.move(_user, 14),
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ]),
      ),
    ));
  }

  // ------------------------------------------------------------------ UI

  Widget _buildMap(MapController c, {bool full = false, VoidCallback? onPick}) {
    return FlutterMap(
      mapController: c,
      options: MapOptions(
        initialCenter: _sel?.pos ?? (_gps ? _user : kRapidCareCoverageCenter),
        initialZoom: 14,
        // Inline preview is locked: no drag, pinch, scroll-zoom or rotate, so the page scrolls
        // normally over it. Pan / zoom only work in the expanded full-screen map.
        interactionOptions: InteractionOptions(flags: full ? InteractiveFlag.all : InteractiveFlag.none),
        onTap: full ? null : (_, __) => _openFullScreenMap(),
        onMapReady: () {
          if (!full) {
            _mapReady = true;
            if (_pendingMapFit) {
              _focusRecommendations();
            } else if (_route.isNotEmpty) {
              _fit(_route);
            }
          }
        },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.rapidcare.app'),
        if (_route.isNotEmpty)
          PolylineLayer(polylines: [Polyline(points: _route, strokeWidth: 5, color: const Color(0xFF1976D2))]),
        MarkerLayer(markers: [
          if (_gps) Marker(
            point: _user,
            width: 40,
            height: 40,
            child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 30),
          ),
          ..._visible.where((h) => h.pos != null).map((h) {
            final selected = _sel?.id == h.id;
            final matches = _matchCount(h, _type == 'Any' ? 'other' : _type.toLowerCase());
            final markerColor = matches == 2 ? _teal : matches == 1 ? Colors.orange.shade800 : Colors.blueGrey.shade600;
            return Marker(
              point: h.pos!,
              width: 48,
              height: 48,
              child: GestureDetector(
                onTap: () {
                  _select(h);
                  onPick?.call();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? Colors.amber : Colors.white, width: selected ? 4 : 2.5),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                ),
              ),
            );
          }),
        ]),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _legendItem(Color color, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF23332E))),
      ]);

  Widget _mapLegend() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _legendItem(_teal, '2/2 listed capabilities'),
          const SizedBox(height: 4),
          _legendItem(Colors.orange.shade800, '1/2 listed'),
          const SizedBox(height: 4),
          _legendItem(Colors.blueGrey.shade600, 'No listed match'),
        ]),
      );

  Widget _stat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ],
  );

  Widget _card(Hospital h) {
    final isSel = _sel?.id == h.id;
    final real = isSel && _routeMin != null;
    final eta = real ? '${_routeMin!.round()} min' : (h.etaMin != null ? '~${h.etaMin} min' : '—');
    final dist = real
        ? '${_routeKm!.toStringAsFixed(1)} km'
        : (h.distanceKm != null ? '~${h.distanceKm} km' : '—');
    final tags = [...h.specialists, ...h.facilities].take(4).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSel ? _teal : Colors.grey.shade200, width: isSel ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_hospital, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              _pill('$dist · $eta', const Color(0xFFE0F2F1), _teal),
            ],
          ),
          const SizedBox(height: 6),
          Text(h.location, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          if (h.recommendationReasons.isNotEmpty || _type != 'Any') ...[
            const SizedBox(height: 5),
            Text(_fitExplanation(h), style: TextStyle(color: _tealDark, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (h.rating != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, color: Colors.amber, size: 15),
                const SizedBox(width: 2),
                Text('${h.rating!.toStringAsFixed(1)} (${h.reviewCount})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            _pill('Directory listing', const Color(0xFFE0F2F1), _teal),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _stat('General Beds', '${h.beds}', Colors.black87),
              Container(height: 24, width: 1, color: Colors.grey.shade300),
              _stat('Critical ICU', '${h.icu}', const Color(0xFFD32F2F)),
            ]),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: tags.map((t) => _pill(t, Colors.grey.shade100, Colors.black87)).toList()),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _teal), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              icon: const Icon(Icons.star_outline, size: 14, color: _teal),
              label: const Text('Reviews', style: TextStyle(fontSize: 12, color: _teal)),
              onPressed: () => showFacilityReviews(context, facilityId: h.id, facilityName: h.name),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.alt_route, size: 14, color: _teal),
              label: const Text('Route', style: TextStyle(fontSize: 12, color: _teal)),
              onPressed: () {
                if (_view == 'List') setState(() => _view = 'Map & List');
                _select(h);
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.navigation, size: 14, color: _teal),
              label: const Text('Navigate', style: TextStyle(fontSize: 12, color: _teal)),
              onPressed: h.pos == null ? null : () => _navigate(h),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.call, size: 14),
              label: Text(h.phone.isEmpty ? 'No phone' : 'Call hospital', style: const TextStyle(fontSize: 12)),
              onPressed: h.phone.isEmpty ? null : () => _call(h),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _viewTab(String label) {
    final on = _view == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _view = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: on ? _tealDark : Colors.grey.shade600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF00695C),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Emergency care near you', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('Hospitals near you',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () async {
                        await _locate();
                        await _load();
                      },
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(_gps ? Icons.gps_fixed : Icons.gps_off, color: const Color(0xFF80CBC4), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _gps
                              ? 'Live GPS · ±${_gpsAccuracy?.round() ?? '?'} m · ${_user.latitude.toStringAsFixed(5)}, ${_user.longitude.toStringAsFixed(5)}'
                              : 'Location not confirmed · hospitals are not distance-ranked',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hospital names, contacts, and map locations are synchronized from the RapidCare directory. Call to confirm current services and capacity.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Emergency type is sent to the backend for the selected flow.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _types
                          .map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t, style: TextStyle(fontSize: 12, color: _type == t ? Colors.white : Colors.black87)),
                          selected: _type == t,
                          selectedColor: _teal,
                          showCheckmark: false,
                          onSelected: (_) {
                            if (_type == t) return;
                            setState(() {
                              _type = t;
                              _sel = null;
                              _route = [];
                              _routeKm = null;
                              _routeMin = null;
                              _pendingMapFit = true;
                            });
                            _load(selectTop: true, focusMap: true);
                          },
                        ),
                      ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: 'Search hospitals or locations...',
                      prefixIcon: const Icon(Icons.search, color: _teal),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [_viewTab('Map & List'), _viewTab('Map View'), _viewTab('List')]),
                  ),
                  const SizedBox(height: 16),

                  if (_loading && _all.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
                  else if (_error != null && _all.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ]),
                    )
                  else ...[
                      if (_view != 'List') ...[
                        Container(
                          height: _view == 'Map View' ? 420 : 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFB2DFDB), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(children: [
                              _buildMap(_map),
                              Positioned(left: 10, top: 10, child: _mapLegend()),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: InkWell(
                                  onTap: _openFullScreenMap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text('Tap to Expand', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ]),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: FloatingActionButton.small(
                                  heroTag: 'relocate_hospital_map_btn',
                                  backgroundColor: _tealDark,
                                  onPressed: () async {
                                    if (!_gps) {
                                      final found = await _locate();
                                      if (found) await _load(silent: true);
                                    }
                                    if (!mounted) return;
                                    try {
                                      _map.move(_gps ? _user : kRapidCareCoverageCenter, 14);
                                    } catch (_) {}
                                  },
                                  child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_sel != null) _card(_sel!),
                      ],
                      if (_type != 'Any' && _all.isNotEmpty &&
                          !_all.any((h) => _matchCount(h, _type.toLowerCase()) == 2))
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD59A)),
                          ),
                          child: Text(
                            'No hospital in the current directory lists both required capabilities for $_type. Matches are directory listings, not confirmed availability; call to verify.',
                            style: const TextStyle(color: Color(0xFF6A4300), fontSize: 12, height: 1.35),
                          ),
                        ),
                      if (_view != 'Map View') ...[
                        const Text('Hospital Directory & ER Availability',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _tealDark)),
                        const SizedBox(height: 4),
                        Text(
                          _type == 'Any'
                          ? (_gps ? 'Ranked by emergency fit and distance' : 'Ranked by listed emergency fit; distance unavailable')
                          : (_gps
                              ? 'Ranked for $_type by listed capabilities and distance; call to confirm current capacity'
                              : 'Ranked for $_type by listed capabilities; distance is unavailable'),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        if (list.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: Text('No hospitals found.', style: TextStyle(color: Colors.grey))),
                          ),
                        ...list.map(_card),
                      ],
                    ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
