import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/api.dart';
import '../../../services/location.dart';

/// Known localities in the Malad and Goregaon coverage area. Used to name the
/// GPS fix when the device geocoder is unavailable (it does not work on web).
class _Locality {
  final String name;
  final double lat, lng;
  const _Locality(this.name, this.lat, this.lng);
}

const _localities = <_Locality>[
  _Locality('Malad West', 19.1860, 72.8350),
  _Locality('Orlem, Malad West', 19.1967, 72.8342),
  _Locality('Mindspace, Malad West', 19.1790, 72.8340),
  _Locality('Malwani, Malad West', 19.2007, 72.8222),
  _Locality('Malad East', 19.1870, 72.8680),
  _Locality('Kurar, Malad East', 19.1990, 72.8667),
  _Locality('Goregaon West', 19.1650, 72.8350),
  _Locality('Jawahar Nagar, Goregaon West', 19.1590, 72.8492),
  _Locality('Siddharth Nagar, Goregaon West', 19.1595, 72.8403),
  _Locality('Pahadi Goregaon', 19.1635, 72.8430),
  _Locality('Goregaon East', 19.1700, 72.8600),
  _Locality('Yashodham, Goregaon East', 19.1760, 72.8590),
  _Locality('Gokuldham, Goregaon East', 19.1723, 72.8685),
  _Locality('Dindoshi, Malad East', 19.1760, 72.8670),
  _Locality('Nagari Niwara, Goregaon East', 19.1745, 72.8780),
  _Locality('Film City, Goregaon East', 19.1620, 72.8800),
  _Locality('Aarey Colony, Goregaon East', 19.1530, 72.8780),
];

/// Names the nearest known Malad/Goregaon locality, e.g.
/// "Nagari Niwara, Goregaon East, Mumbai". Falls back to "Mumbai, Maharashtra".
String _nearestArea(LatLng point) {
  const distance = Distance();
  _Locality? best;
  double bestKm = double.infinity;
  for (final area in _localities) {
    final d = distance.as(
      LengthUnit.Kilometer,
      point,
      LatLng(area.lat, area.lng),
    );
    if (d < bestKm) {
      bestKm = d;
      best = area;
    }
  }
  if (best == null || bestKm > 5) return 'Mumbai, Maharashtra';
  return '${best.name}, Mumbai';
}

class EmergencyLocationScreen extends StatefulWidget {
  final String location;
  final ValueChanged<String> onLocationChanged;

  // Sends the actual GPS coordinates back to PatientEmergency.
  final ValueChanged<LatLng?>? onLatLngChanged;
  final ValueChanged<bool>? onManualLocationChanged;

  final VoidCallback onNext;

  const EmergencyLocationScreen({
    super.key,
    required this.location,
    required this.onLocationChanged,
    this.onLatLngChanged,
    this.onManualLocationChanged,
    required this.onNext,
  });

  @override
  State<EmergencyLocationScreen> createState() =>
      _EmergencyLocationScreenState();
}

class _EmergencyLocationScreenState extends State<EmergencyLocationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  final MapController _mapController = MapController();

  String _currentAddress = '';
  String _latLngText = 'Waiting for a fresh device GPS fix…';
  double? _accuracyMeters;

  bool _isLoadingLocation = true;
  bool _hasConfirmedLocation = false;
  bool _isManualLocation = false;
  bool _locationRequestBusy = false;

  LatLng _currentLatLng =
      kRapidCareCoverageCenter; // camera only until a fix or manual pin is chosen

  @override
  void initState() {
    super.initState();

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _currentAddress = widget.location;

    // FIX 1: wait until the first frame is built, so the parent callbacks
    // (which may call setState on the parent) don't run during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _determinePosition();
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    if (_locationRequestBusy) return;
    _locationRequestBusy = true;

    // FIX 2: everything is inside try/finally, so the busy flag
    // always resets even if something throws.
    try {
      widget.onLatLngChanged?.call(null);
      widget.onManualLocationChanged?.call(false);
      if (mounted) {
        setState(() {
          _hasConfirmedLocation = false;
          _isManualLocation = false;
          _accuracyMeters = null;
          _isLoadingLocation = true;
          _latLngText = 'Checking location permission and GPS…';
        });
      }

      final Position position = await getFreshLocation(
        onPosition: (fix) {
          if (!mounted || !_isLoadingLocation) return;
          setState(() {
            _latLngText =
            'GPS fix received (±${fix.accuracy.round()} m); checking for a better fix…';
          });
        },
      );

      final fetchedLatLng = LatLng(position.latitude, position.longitude);
      final latLngFormatted =
          'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
      final areaName = _nearestArea(fetchedLatLng);
      final accuracyNotice = position.accuracy > 100
          ? 'Approximate location (±${position.accuracy.round()} m). Verify the pin on the map.'
          : 'GPS accuracy ±${position.accuracy.round()} m.';
      if (!mounted) return;
      setState(() {
        _currentLatLng = fetchedLatLng;
        _currentAddress = areaName;
        _latLngText = '$latLngFormatted\n$accuracyNotice';
        _isLoadingLocation = false;
        _hasConfirmedLocation = true;
        _isManualLocation = false;
        _accuracyMeters = position.accuracy;
      });
      widget.onLatLngChanged?.call(fetchedLatLng);
      widget.onManualLocationChanged?.call(false);
      widget.onLocationChanged('$areaName ($latLngFormatted)');
      _mapController.move(fetchedLatLng, 15.0);

      try {
        final placemarks = await geo.Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 8));
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts =
          [place.subLocality, place.locality, place.administrativeArea]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toSet()
              .toList();
          final address = parts.isEmpty ? areaName : parts.join(', ');
          if (mounted) setState(() => _currentAddress = address);
          widget.onLocationChanged('$address ($latLngFormatted)');
        }
      } catch (_) {
        // GPS and its coordinates remain usable if address lookup is unavailable.
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _latLngText =
          'Location lookup timed out. Retry, allow location access, or tap the map to set your pickup point.';
          _currentAddress = 'Location not confirmed';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _latLngText =
          '${e.toString().replaceFirst('Exception: ', '')} Tap Retry or select the pickup point on the map.';
          _currentAddress = 'Location not confirmed';
          _isLoadingLocation = false;
        });
      }
    } finally {
      _locationRequestBusy = false;
    }
  }

  void _setMapPickupPoint(LatLng point) {
    final formatted =
        'Map pin: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    setState(() {
      _currentLatLng = point;
      _currentAddress = 'Manually selected map location';
      _latLngText = formatted;
      _isLoadingLocation = false;
      _hasConfirmedLocation = true;
      _isManualLocation = true;
      _accuracyMeters = null;
    });
    widget.onLatLngChanged?.call(point);
    widget.onManualLocationChanged?.call(true);
    widget.onLocationChanged('Manually selected map location ($formatted)');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ---------------------------------------------------------
        // HEADER
        // ---------------------------------------------------------
        Container(
          color: const Color(0xFFD32F2F),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _dotController,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'EMERGENCY ASSISTANCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Step 1 of 5',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                child: const Text(
                  'Exit',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // ---------------------------------------------------------
        // MAIN CONTENT
        // ---------------------------------------------------------
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Your Pickup Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Ambulance GPS navigation will guide to this pinpoint',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 3),
                Text(
                  'If GPS is unavailable, tap the map to place your pickup pin.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 14),

                // -------------------------------------------------
                // OPENSTREETMAP
                // -------------------------------------------------
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _hasConfirmedLocation
                                ? _currentLatLng
                                : kRapidCareCoverageCenter,
                            initialZoom: 15.0,
                            onTap: (_, point) => _setMapPickupPoint(point),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.rapidcare_k',
                            ),

                            MarkerLayer(
                              markers: [
                                if (_hasConfirmedLocation)
                                  Marker(
                                    point: _currentLatLng,
                                    width: 80,
                                    height: 80,
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.location_pin,
                                          color: Color(0xFFD32F2F),
                                          size: 36,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // -------------------------------------------------
                        // ADDRESS BADGE
                        // -------------------------------------------------
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                _isLoadingLocation
                                    ? 'Locating...'
                                    : _hasConfirmedLocation
                                    ? _currentAddress
                                    : 'Approximate map point · tap to set pickup',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),

                        // -------------------------------------------------
                        // MAP CONTROLS
                        // -------------------------------------------------
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Column(
                            children: [
                              _mapButton(
                                Icons.add,
                                onPressed: () {
                                  final double zoom =
                                      _mapController.camera.zoom + 1;

                                  _mapController.move(
                                    _mapController.camera.center,
                                    zoom,
                                  );
                                },
                              ),

                              const SizedBox(height: 4),

                              _mapButton(
                                Icons.remove,
                                onPressed: () {
                                  final double zoom =
                                      _mapController.camera.zoom - 1;

                                  _mapController.move(
                                    _mapController.camera.center,
                                    zoom,
                                  );
                                },
                              ),

                              const SizedBox(height: 4),

                              _mapButton(
                                Icons.refresh,
                                onPressed: _determinePosition,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ---------------------------------------------------------
                // LOCATION CARD
                // ---------------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Color(0xFFD32F2F),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'PICKUP LOCATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _isLoadingLocation
                            ? 'Getting your current GPS position…'
                            : _currentAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _latLngText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),

                      const Divider(height: 20),

                      Row(
                        children: [
                          _locationChip(
                            _isManualLocation
                                ? 'Manual map pin'
                                : (_hasConfirmedLocation
                                ? 'Live GPS fix'
                                : 'Location not confirmed'),
                          ),
                          const SizedBox(width: 8),
                          _locationChip(
                            _isManualLocation
                                ? 'Tap map to adjust'
                                : (_accuracyMeters == null
                                ? 'Waiting for GPS'
                                : 'GPS ±${_accuracyMeters!.round()} m'),
                          ),
                        ],
                      ),
                      if (!_hasConfirmedLocation && !_isLoadingLocation) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _determinePosition,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Try GPS again'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ---------------------------------------------------------
        // CONFIRM LOCATION
        // ---------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (!_hasConfirmedLocation) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Confirm your pickup location with GPS or tap the map to place a pin.',
                      ),
                    ),
                  );
                  return;
                }
                widget.onNext();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'CONFIRM LOCATION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: Colors.black87),
        onPressed: onPressed ?? () {},
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _locationChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
      ),
    );
  }
}