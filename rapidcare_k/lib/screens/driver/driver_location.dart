import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/api.dart';
import '../../services/location.dart';
import '../patient/facility_reviews.dart';

const _order = [
  'incoming',
  'accepted',
  'en_route',
  'arrived',
  'picked_up',
  'reached_hospital',
  'completed',
];

// current status -> [button text, next status]
const Map<String, List<String>> _next = {
  'incoming': ['Accept Emergency', 'accepted'],
  'accepted': ['Start Driving to Patient', 'en_route'],
  'en_route': ['Arrived at Patient Location', 'arrived'],
  'arrived': ['Patient Picked Up', 'picked_up'],
  'picked_up': ['Reached Hospital', 'reached_hospital'],
  'reached_hospital': ['Complete Handover', 'completed'],
};

class DriverLocationScreen extends StatefulWidget {
  final String patientName;
  final String pickupLocation;
  final String hospitalDestination;
  final int ambulanceId; // this driver's ambulance; the dashboard should pass the logged-in one

  const DriverLocationScreen({
    super.key,
    required this.patientName,
    required this.pickupLocation,
    required this.hospitalDestination,
    required this.ambulanceId,
  });

  @override
  State<DriverLocationScreen> createState() => _DriverLocationScreenState();
}

class _DriverLocationScreenState extends State<DriverLocationScreen> {
  final _map = MapController();
  bool _ready = false,
      _centered = false,
      _gpsErr = false,
      _connErr = false,
      _busy = false,
      _polling = false;
  LatLng? _me;
  DateTime? _lastGpsAt;
  String? _gpsMessage;
  Map<String, dynamic>? _case;
  RoadRoute? _route;
  Timer? _gpsT, _pollT;
  int _tick = 0;
  bool _sendingGps = false;
  String?
  _fitKey; // camera is re-fitted only when the case or its status changes
  bool _fitPending = false;

  @override
  void initState() {
    super.initState();
    _sendGps();
    _poll();
    _gpsT = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _sendGps(requestPermission: false),
    );
    _pollT = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _gpsT?.cancel();
    _pollT?.cancel();
    super.dispose();
  }

  /// Sends this ambulance's live position. This is also what makes the ambulance "online"
  /// for dispatch, and it is what the patient's map shows.
  Future<void> _sendGps({bool requestPermission = true}) async {
    if (_sendingGps) return;
    _sendingGps = true;
    LatLng me;
    double accuracy;
    try {
      final pos = await getFreshLocation(
        requestPermission: requestPermission,
        onPosition: (fix) {
          if (!mounted) return;
          setState(() {
            _gpsMessage =
                'GPS fix ±${fix.accuracy.round()} m · checking for a more precise fix…';
          });
        },
      );
      me = LatLng(pos.latitude, pos.longitude);
      accuracy = pos.accuracy;
      if (mounted) {
        setState(() {
          _gpsMessage =
              '${accuracy > 100 ? 'Approximate GPS' : 'GPS'} ±${accuracy.round()} m';
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _gpsErr = true;
          _gpsMessage = e.toString().replaceFirst('Exception: ', '');
        });
      _sendingGps = false;
      return;
    }
    if (!mounted) {
      _sendingGps = false;
      return;
    }
    setState(() {
      _me = me;
      _gpsErr = false;
      _gpsMessage =
          '${accuracy > 100 ? 'Approximate location' : 'Live GPS fix'} · ±${accuracy.round()} m';
    });
    if (_ready && !_centered) {
      _centered = true;
      try {
        _map.move(me, 15);
      } catch (_) {}
    }
    if (_fitPending && _case != null) {
      _fitPending = !_fit(_target(_case!));
    }
    try {
      await api(
        '/api/driver/location',
        method: 'POST',
        body: {
          'ambulance_id': widget.ambulanceId,
          'lat': me.latitude,
          'lng': me.longitude,
        },
      );
      if (mounted)
        setState(() {
          _lastGpsAt = DateTime.now();
          _connErr = false;
        });
    } catch (_) {
      if (mounted) setState(() => _connErr = true);
    } finally {
      _sendingGps = false;
    }
  }

  LatLng? _target(Map<String, dynamic> c) =>
      latLngOf(_order.indexOf('${c['status']}') >= 4 ? c['hospital_info'] : c);

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final r = await api('/api/driver/${widget.ambulanceId}/case');
      if (!mounted) {
        _sendingGps = false;
        return;
      }
      final c = (r is Map && r.isNotEmpty)
          ? Map<String, dynamic>.from(r)
          : null;
      setState(() {
        _case = c;
        _connErr = false;
        if (c == null) _route = null;
      });
      if (c == null) {
        _fitKey = null;
        return;
      }
      final target = _target(c);
      final key = '${c['id']}:${c['status']}';
      final changed = key != _fitKey;
      if (changed) {
        _fitKey = key;
        _fitPending = true;
        _tick = 0;
        setState(() => _route = null); // new leg of the trip: drop the old line
      }
      if (_me != null && target != null && _tick++ % 2 == 0) {
        final rt = await roadRoute(_me!, target);
        if (mounted && rt != null) setState(() => _route = rt);
      }
      if (changed || _fitPending) {
        _fitPending = !_fit(target);
      }
    } catch (_) {
      if (mounted) setState(() => _connErr = true);
    } finally {
      _polling = false;
    }
  }

  bool _fit(LatLng? target) {
    if (!_ready || _me == null || target == null) return false;
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([_me!, target]),
          padding: const EdgeInsets.all(56),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _advance(String status) async {
    final c = _case;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    try {
      await api(
        '/api/app/emergency/${c['id']}',
        method: 'PATCH',
        body: {'status': status},
      );
      if (status == 'completed' && mounted) {
        final hospital = c['hospital_info'];
        final hospitalId = hospital is Map ? hospital['id'] : c['hospital_id'];
        final hospitalName = hospital is Map
            ? (hospital['name'] ?? c['hospital'] ?? widget.hospitalDestination)
                  .toString()
            : (c['hospital'] ?? widget.hospitalDestination).toString();
        if (hospitalId is num) {
          await showFacilityReviews(
            context,
            facilityId: hospitalId.toInt(),
            facilityName: hospitalName,
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Handover complete. Returning to your dispatch screen.',
            ),
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      await _poll();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update status. Check the connection.'),
          ),
        );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmAdvance(List<String> action) async {
    final status = action[1];
    final prompt = switch (status) {
      'accepted' => 'Accept this emergency dispatch and start the trip?',
      'picked_up' => 'Confirm that the patient is safely with you?',
      'reached_hospital' =>
        'Confirm that you have arrived at the selected hospital?',
      'completed' => 'Confirm that the hospital handover is complete?',
      _ => null,
    };
    if (prompt != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm trip update'),
          content: Text(prompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    await _advance(status);
  }

  @override
  Widget build(BuildContext context) {
    final c = _case;
    final st = c?['status'] as String?;
    final toHospital = st != null && _order.indexOf(st) >= 4;
    final patient = c == null ? null : latLngOf(c);
    final hospital = latLngOf(c?['hospital_info']);
    final act = st == null ? null : _next[st];

    final String sub = _gpsErr
        ? (_gpsMessage ?? 'GPS unavailable. Check location settings.')
        : _connErr
        ? 'Cannot reach the dispatch server. Retrying…'
        : c == null
        ? 'You are online and visible to dispatch'
        : st == 'incoming'
        ? 'New emergency assigned to you. Accept to start'
        : 'Heading to ${toHospital ? (c['hospital'] ?? widget.hospitalDestination) : 'patient pickup'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Navigation & Tracking',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF004D40),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.turn_right, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _route?.next ??
                            (c == null
                                ? 'Waiting for an emergency assignment…'
                                : 'Calculating route…'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: TextStyle(
                          color: (_gpsErr || _connErr)
                              ? Colors.amber
                              : Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_lastGpsAt != null || _gpsErr || _connErr)
            Container(
              width: double.infinity,
              color: _connErr || _gpsErr
                  ? Colors.amber.shade50
                  : Colors.teal.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                _connErr
                    ? 'Server connection lost · retrying automatically'
                    : _gpsErr
                    ? (_gpsMessage ?? 'GPS unavailable')
                    : 'Last location sent ${TimeOfDay.fromDateTime(_lastGpsAt!).format(context)}',
                style: TextStyle(
                  fontSize: 11,
                  color: _connErr || _gpsErr
                      ? Colors.deepOrange.shade900
                      : Colors.teal.shade900,
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _me ?? patient ?? kRapidCareCoverageCenter,
                    initialZoom: 15,
                    onMapReady: () {
                      _ready = true;
                      if (_me != null && !_centered) {
                        _centered = true;
                        _map.move(_me!, 15);
                      }
                      if (_fitPending && _case != null) {
                        _fitPending = !_fit(_target(_case!));
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.rapidcare_k',
                    ),
                    if (_route != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route!.points,
                            strokeWidth: 5,
                            color: const Color(0xFF1976D2),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (patient != null)
                          Marker(
                            point: patient,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Color(0xFFD32F2F),
                              size: 38,
                            ),
                          ),
                        if (hospital != null)
                          Marker(
                            point: hospital,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.local_hospital,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        if (_me != null)
                          Marker(
                            point: _me!,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.navigation,
                              color: Color(0xFF00695C),
                              size: 36,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer,
                          size: 14,
                          color: Color(0xFF00695C),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _route == null
                              ? 'ETA: —'
                              : 'ETA: ${_route!.min.round()} min (${_route!.km.toStringAsFixed(1)} km)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'driver_recenter',
                    backgroundColor: const Color(0xFF004D40),
                    onPressed: () {
                      if (_me == null) {
                        _sendGps(requestPermission: true);
                        return;
                      }
                      final t = c == null ? null : _target(c);
                      if (t != null) {
                        _fit(t);
                      } else {
                        _map.move(_me!, 15);
                      }
                    },
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Patient:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Flexible(
                      child: Text(
                        '${c?['patient_name'] ?? widget.patientName}${c?['emergency_type'] != null ? ' · ${c!['emergency_type']}' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pickup Point:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Flexible(
                      child: Text(
                        patient != null
                            ? '${patient.latitude.toStringAsFixed(4)}, ${patient.longitude.toStringAsFixed(4)}'
                            : widget.pickupLocation,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Destination ER:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Flexible(
                      child: Text(
                        '${c?['hospital'] ?? widget.hospitalDestination}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (act == null || _busy)
                        ? null
                        : () => _confirmAdvance(act),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            act == null ? 'No active emergency' : act[0],
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
