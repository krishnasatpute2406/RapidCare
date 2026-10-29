import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api.dart';
import '../../../services/location.dart';
import '../facility_reviews.dart';

const _red = Color(0xFFD32F2F);
const _order = ['incoming', 'accepted', 'en_route', 'arrived', 'picked_up', 'reached_hospital', 'completed'];
const _label = {
  'incoming': 'AMBULANCE ALLOCATED',
  'accepted': 'DRIVER ACCEPTED',
  'en_route': 'AMBULANCE EN ROUTE',
  'arrived': 'PARAMEDICS ARRIVED',
  'picked_up': 'PATIENT PICKED UP',
  'reached_hospital': 'REACHED HOSPITAL',
  'completed': 'EMERGENCY COMPLETED',
  'cancelled': 'CANCELLED',
};

class EmergencyAssignedScreen extends StatefulWidget {
  final String hospitalName;
  final VoidCallback onCancel;
  final bool isDriverOnline; // kept so existing callers still compile
  final int? emergencyId, hospitalId;
  final double? lat, lng; // patient position; read from GPS here if not passed
  final bool trackLiveLocation;
  final String? accessToken;
  final String emergencyType;
  final String patientName;
  final String patientPhone;

  const EmergencyAssignedScreen({
    super.key,
    required this.hospitalName,
    required this.onCancel,
    this.isDriverOnline = true,
    this.emergencyId,
    this.hospitalId,
    this.lat,
    this.lng,
    this.trackLiveLocation = true,
    this.accessToken,
    this.emergencyType = 'other',
    this.patientName = '',
    this.patientPhone = '',
  });

  @override
  State<EmergencyAssignedScreen> createState() => _EmergencyAssignedScreenState();
}

class _EmergencyAssignedScreenState extends State<EmergencyAssignedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _dot =
  AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..repeat(reverse: true);
  final _map = MapController();
  bool _ready = false, _polling = false;
  int? _id;
  String? _patientAccessToken;
  Map<String, dynamic>? _c;
  String? _err;
  Timer? _t;
  Timer? _locationT;
  bool _locationUpdateBusy = false;
  int _tick = 0;
  RoadRoute? _route;
  DateTime _since = DateTime.now(); // when we started looking for an ambulance

  @override
  void initState() {
    super.initState();
    _patientAccessToken = widget.accessToken;
    _begin();
  }

  @override
  void dispose() {
    _t?.cancel();
    _locationT?.cancel();
    _dot.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() => _err = null);
    _t?.cancel();
    try {
      var id = _id ?? widget.emergencyId; // retry reuses the case we already created
      if (id == null) {
        var la = widget.lat, ln = widget.lng;
        if (la == null || ln == null) {
          final pos = await getFreshLocation();
          la = pos.latitude;
          ln = pos.longitude;
        }
        final r = await api('/api/app/emergency', method: 'POST', body: {
          'emergency_type': widget.emergencyType.toLowerCase(),
          'patient_name': widget.patientName,
          'patient_phone': widget.patientPhone,
          'hospital_id': widget.hospitalId,
          'lat': la,
          'lng': ln,
        });
        id = r['emergency']['id'] as int;
        _patientAccessToken = r['access_token']?.toString();
      }
      if (_patientAccessToken == null || _patientAccessToken!.isEmpty) {
        throw Exception('The emergency session token was not returned. Start a new emergency request.');
      }
      _id = id;
      _since = DateTime.now();
      await _poll();
      _t = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
      if (widget.trackLiveLocation && !{'completed', 'cancelled'}.contains(_c?['status'])) {
        _locationT = Timer.periodic(const Duration(seconds: 20), (_) => _updatePatientLocation());
      }
    } catch (_) {
      if (mounted) setState(() => _err = 'Could not start the request. Check the server connection and location permission.');
    }
  }

  Future<void> _updatePatientLocation() async {
    if (_id == null || _locationUpdateBusy || !widget.trackLiveLocation) return;
    _locationUpdateBusy = true;
    try {
      final position = await getFreshLocation(requestPermission: false);
      await api('/api/app/emergency/$_id/location', method: 'POST', body: {
        'lat': position.latitude,
        'lng': position.longitude,
      }, headers: {'Authorization': 'Bearer $_patientAccessToken'});
    } catch (_) {
      // Keep dispatch running; the next interval retries with a fresh fix.
    } finally {
      _locationUpdateBusy = false;
    }
  }

  Future<void> _poll() async {
    if (_id == null || _polling) return;
    _polling = true;
    try {
      final c = Map<String, dynamic>.from(await api('/api/app/emergency/$_id', headers: {'Authorization': 'Bearer $_patientAccessToken'}));
      if (!mounted) return;
      setState(() => _c = c);
      final st = c['status'] as String;
      if (st == 'completed' || st == 'cancelled') {
        _t?.cancel();
        _locationT?.cancel();
        return;
      }
      final amb = latLngOf(c['ambulance_info']);
      final target = latLngOf(_order.indexOf(st) >= 4 ? c['hospital_info'] : c);
      if (amb != null && target != null && _tick++ % 3 == 0) {
        final r = await roadRoute(amb, target);
        if (mounted && r != null) setState(() => _route = r);
      }
      _fit();
    } catch (_) {
      // keep the last known state; the next poll retries
    } finally {
      _polling = false;
    }
  }

  void _fit() {
    final c = _c;
    if (!_ready || c == null) return;
    final toHospital = _order.indexOf(c['status']) >= 4;
    final pts = [latLngOf(c), latLngOf(c['ambulance_info']), if (toHospital) latLngOf(c['hospital_info'])].whereType<LatLng>().toList();
    if (pts.length < 2) return;
    try {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(48)));
    } catch (_) {}
  }

  Future<void> _cancel() async {
    try {
      if (_id != null && _patientAccessToken != null) {
        await api('/api/app/emergency/$_id', method: 'PATCH', body: {'status': 'cancelled'}, headers: {'Authorization': 'Bearer $_patientAccessToken'});
      }
    } catch (_) {}
    widget.onCancel();
  }

  Future<void> _dial(String number) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please dial $number')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Column(children: [
      _header(),
      Expanded(
        child: (_err != null && c == null)
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: _red)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _begin, child: const Text('Retry')),
              const SizedBox(height: 6),
              TextButton.icon(onPressed: () => _dial('108'), icon: const Icon(Icons.call, color: _red, size: 16), label: const Text('Call 108', style: TextStyle(color: _red))),
            ]),
          ),
        )
            : c == null
            ? const Center(child: CircularProgressIndicator())
            : _body(c),
      ),
      if (c != null) _actions(c),
    ]);
  }

  Widget _header() => Container(
    color: _red,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          FadeTransition(
            opacity: _dot,
            child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 6),
          const Text('EMERGENCY ASSISTANCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 2),
        const Text('Step 5 of 5 • Live Tracking', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
      OutlinedButton(
        onPressed: _cancel,
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
        child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
    ]),
  );

  Widget _box({required Widget child, Color? border}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: border ?? Colors.grey.shade300)),
    child: child,
  );

  /// Shown while no ambulance is assigned. After 40 s it stops spinning and offers 108.
  Widget _searching() {
    final waited = DateTime.now().difference(_since).inSeconds;
    if (waited < 40) {
      return const Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 10),
        Expanded(child: Text('Searching for the nearest available ambulance…', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('No ambulance is online near you right now.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _red)),
      const SizedBox(height: 4),
      const Text('We keep trying in the background. If this is urgent, call the 108 control room now.', style: TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _dial('108'),
          icon: const Icon(Icons.call, color: Colors.white, size: 16),
          label: const Text('Call 108 now', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: _red),
        ),
      ),
    ]);
  }

  Widget _body(Map<String, dynamic> c) {
    final st = c['status'] as String;
    final idx = _order.indexOf(st);
    final amb = c['ambulance_info'] as Map?;
    final gpsLive = amb?['location_is_live'] == true;
    final gpsAge = amb?['gps_age_seconds'];
    final pat = latLngOf(c), ambPos = latLngOf(amb), hos = latLngOf(c['hospital_info']);
    final eta = _route != null ? '${_route!.min.round()} min' : (c['eta'] ?? '—');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ambulance card
        _box(
          border: st == 'cancelled' ? Colors.orange.shade300 : Colors.red.shade100,
          child: st == 'cancelled'
              ? const Text('Emergency cancelled', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))
              : amb == null
              ? _searching()
              : Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                child: Text(_label[st] ?? st.toUpperCase(), style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              Text(idx >= 5 ? 'ARRIVED' : 'ETA: $eta', style: const TextStyle(fontWeight: FontWeight.bold, color: _red, fontSize: 13)),
            ]),
            if (st == 'incoming')
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Align(alignment: Alignment.centerLeft, child: Text('Waiting for the driver to accept…', style: TextStyle(fontSize: 11, color: Colors.grey))),
              ),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Driver', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('${amb['driver']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${amb['phone'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Vehicle & Distance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('${amb['vehicle_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${amb['type']} • ${_route != null ? '${_route!.km.toStringAsFixed(1)} km away' : 'locating…'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _red)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // Live map: patient, ambulance (moves with the driver's GPS), hospital
        Container(
          height: 260,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: pat ?? ambPos ?? kRapidCareCoverageCenter,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    onMapReady: () {
                      _ready = true;
                      _fit();
                    },
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.rapidcare_k'),
                    if (_route != null) PolylineLayer(polylines: [Polyline(points: _route!.points, strokeWidth: 5, color: const Color(0xFF1976D2))]),
                    MarkerLayer(markers: [
                      if (pat != null) Marker(point: pat, width: 40, height: 40, child: const Icon(Icons.person_pin_circle, color: _red, size: 38)),
                      if (hos != null) Marker(point: hos, width: 40, height: 40, child: const Icon(Icons.local_hospital, color: Colors.blue, size: 30)),
                      if (ambPos != null)
                        Marker(
                          point: ambPos,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: gpsLive ? const Color(0xFF00695C) : Colors.orange.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                            ),
                            child: const Icon(Icons.local_shipping, color: Colors.white, size: 22),
                          ),
                        ),
                    ]),
                  ],
                ),
                if (amb != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: gpsLive ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text(
                        gpsLive
                            ? 'LIVE · updated ${gpsAge is num ? '${gpsAge.toInt()}s ago' : 'now'}'
                            : 'GPS signal delayed${gpsAge is num ? ' · ${gpsAge.toInt()}s old' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: gpsLive ? Colors.green.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Progress
        _box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Emergency Dispatch Progress:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Flexible(child: Text(widget.hospitalName, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _red))),
            ]),
            const SizedBox(height: 10),
            _step('1. Nearest Ambulance Allocated${amb != null ? ' (${amb['vehicle_number']})' : ''}', amb != null),
            _step('2. Ambulance En Route to Your Location', idx >= 2),
            _step('3. Paramedics Arrived at Pickup Point', idx >= 3),
            _step('4. Patient Picked Up (In Transit to ER)', idx >= 4),
            _step('5. Arrived at Hospital Emergency Bay', idx >= 5),
            _step('6. Patient Handover Completed', idx >= 6),
          ]),
        ),
      ]),
    );
  }

  Widget _actions(Map<String, dynamic> c) {
    final st = c['status'] as String;
    final phone = ((c['ambulance_info'] as Map?)?['phone'] ?? '').toString();
    final over = st == 'completed' || st == 'cancelled';
    if (st == 'completed' && widget.hospitalId != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showFacilityReviews(
                context,
                facilityId: widget.hospitalId!,
                facilityName: widget.hospitalName,
              ),
              icon: const Icon(Icons.star_rounded, size: 17),
              label: const Text('Rate Hospital'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (!over && phone.isNotEmpty) ? () => _dial(phone) : null,
            icon: const Icon(Icons.call, color: Colors.white, size: 14),
            label: const Text('Call Driver', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: over ? () => Navigator.of(context).pop() : _cancel,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _red), padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Text(over ? 'Close' : 'Cancel Emergency', style: const TextStyle(color: _red)),
          ),
        ),
      ]),
    );
  }

  Widget _step(String title, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: done ? _red : Colors.grey),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: done ? Colors.black87 : Colors.grey))),
    ]),
  );
}
