import 'dart:async';

import 'package:flutter/material.dart';

import 'driver_location.dart';
import '../../services/api.dart';
import '../../services/location.dart';
import '../patient/patient_dashboard.dart';

String _stageLabel(String status) =>
    const {
      'incoming': 'New dispatch',
      'accepted': 'Dispatch accepted',
      'en_route': 'Driving to patient',
      'arrived': 'At pickup location',
      'picked_up': 'Patient onboard',
      'reached_hospital': 'At hospital',
      'completed': 'Handover complete',
    }[status] ??
    status.replaceAll('_', ' ');

class DriverDashboard extends StatefulWidget {
  final Map<String, dynamic> driver;
  const DriverDashboard({super.key, required this.driver});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isOnline = true, _loadingCase = true, _savingStatus = false;
  bool _gpsAvailable = false,
      _serverUnavailable = false,
      _locationBusy = false,
      _loggingOut = false;
  String _gpsMessage = 'Checking location permission and GPS…';
  Map<String, dynamic>? _case;
  Timer? _caseTimer, _gpsTimer;
  DateTime? _lastGpsAt;
  int? _lastCaseId;
  bool _caseRequestBusy = false;
  int get _ambulanceId => widget.driver['id'] as int;

  @override
  void initState() {
    super.initState();
    _isOnline = (widget.driver['status'] ?? 'Available') != 'Offline';
    _loadCase();
    _caseTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadCase(silent: true),
    );
    _sendLocation();
    _gpsTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_isOnline) _sendLocation(requestPermission: false);
    });
  }

  @override
  void dispose() {
    _caseTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCase({bool silent = false}) async {
    if (_caseRequestBusy) return;
    _caseRequestBusy = true;
    try {
      final c = await api('/api/driver/$_ambulanceId/case');
      if (!mounted) return;
      final next = c is Map && c.isNotEmpty
          ? Map<String, dynamic>.from(c)
          : null;
      final nextId = next?['id'] as int?;
      final isNew = nextId != null && nextId != _lastCaseId;
      setState(() {
        _case = next;
        _lastCaseId = nextId;
        _serverUnavailable = false;
        _loadingCase = false;
      });
      if (isNew && silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New dispatch assigned${next?['code'] == null ? '' : ': ${next?['code']}'}',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _serverUnavailable = true;
          _loadingCase = false;
        });
    } finally {
      _caseRequestBusy = false;
    }
  }

  Future<void> _sendLocation({bool requestPermission = true}) async {
    if (!_isOnline || _locationBusy) return;
    _locationBusy = true;
    var gpsFixObtained = false;
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
      gpsFixObtained = true;
      final approximate = pos.accuracy > 100;
      if (mounted)
        setState(() {
          _gpsMessage = approximate
              ? 'Approximate GPS ±${pos.accuracy.round()} m · sending location to dispatch…'
              : 'GPS ±${pos.accuracy.round()} m · sending location to dispatch…';
          _serverUnavailable = false;
        });
      await api(
        '/api/driver/location',
        method: 'POST',
        body: {
          'ambulance_id': _ambulanceId,
          'lat': pos.latitude,
          'lng': pos.longitude,
        },
      );
      if (mounted)
        setState(() {
          _gpsAvailable = true;
          _gpsMessage =
              '${approximate ? 'Approximate location' : 'GPS'} ±${pos.accuracy.round()} m shared · updated ${TimeOfDay.fromDateTime(DateTime.now()).format(context)}';
          _lastGpsAt = DateTime.now();
          _serverUnavailable = false;
        });
    } on TimeoutException {
      if (mounted)
        setState(() {
          _gpsAvailable = false;
          _serverUnavailable = gpsFixObtained;
          _gpsMessage = gpsFixObtained
              ? 'GPS fix found, but the dispatch server did not respond. Retrying…'
              : 'GPS fix timed out. Check device location settings and retry.';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _gpsAvailable = false;
          _serverUnavailable = gpsFixObtained;
          _gpsMessage = gpsFixObtained
              ? 'GPS fix found, but the dispatch server could not be updated. Retrying…'
              : e.toString().replaceFirst('Exception: ', '');
        });
    } finally {
      _locationBusy = false;
    }
  }

  Future<void> _toggleOnline() async {
    if (_savingStatus) return;
    if (_isOnline && _case != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish the active emergency before going Offline.'),
        ),
      );
      return;
    }
    final next = !_isOnline;
    setState(() => _savingStatus = true);
    try {
      final result = await api(
        '/api/driver/$_ambulanceId/status',
        method: 'PATCH',
        body: {'status': next ? 'Available' : 'Offline'},
      );
      if (!mounted) return;
      setState(() {
        _isOnline =
            (result['driver']?['status'] ?? (next ? 'Available' : 'Offline')) !=
            'Offline';
        _serverUnavailable = false;
      });
      if (_isOnline) _sendLocation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isOnline
                ? 'You are online and available for dispatch.'
                : 'You are offline and will not receive dispatches.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _serverUnavailable = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update shift status: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('End Shift & Logout?'),
          content: Text(
            _case == null
                ? 'RapidCare will set your ambulance Offline, then return to the patient home screen.'
                : 'You still have an active emergency. Complete the handover before ending your shift.',
          ),
          actions: [
            TextButton(
              onPressed: _loggingOut ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (_case == null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                ),
                onPressed: _loggingOut
                    ? null
                    : () async {
                        setDialog(() => _loggingOut = true);
                        try {
                          await api(
                            '/api/driver/$_ambulanceId/status',
                            method: 'PATCH',
                            body: {'status': 'Offline'},
                          );
                          if (!mounted) return;
                          setApiToken(null);
                          _caseTimer?.cancel();
                          _gpsTimer?.cancel();
                          Navigator.pop(ctx);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PatientDashboard(),
                            ),
                          );
                        } catch (_) {
                          if (!ctx.mounted) return;
                          setDialog(() => _loggingOut = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not confirm Offline status. Check your connection and try again.',
                              ),
                            ),
                          );
                        }
                      },
                child: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Go Offline & Logout',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.driver['driver'] ?? 'Driver'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.driver['vehicle_number'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _loadCase,
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 21,
                      ),
                      tooltip: 'Refresh dispatch',
                    ),
                    IconButton(
                      onPressed: _handleLogout,
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white70,
                        size: 22,
                      ),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Unit Dispatch Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        InkWell(
                          onTap: _savingStatus ? null : _toggleOnline,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _savingStatus
                                      ? 'UPDATING…'
                                      : _isOnline
                                      ? 'ONLINE (RECEIVING)'
                                      : 'OFFLINE',
                                  style: TextStyle(
                                    color: _isOnline
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          _gpsAvailable ? Icons.gps_fixed : Icons.gps_not_fixed,
                          size: 15,
                          color: _gpsAvailable ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            !_isOnline
                                ? 'Offline · GPS sharing paused'
                                : _gpsMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: _gpsAvailable
                                  ? Colors.green.shade800
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (_serverUnavailable)
                          const Tooltip(
                            message: 'Cannot reach RapidCare server',
                            child: Icon(
                              Icons.cloud_off,
                              color: Colors.red,
                              size: 17,
                            ),
                          ),
                        if (_isOnline)
                          IconButton(
                            tooltip: 'Retry or refresh GPS location',
                            onPressed: _locationBusy
                                ? null
                                : () => _sendLocation(requestPermission: true),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: Icon(
                              Icons.refresh,
                              size: 18,
                              color: _gpsAvailable ? Colors.green : Colors.orange,
                            ),
                          ),
                      ],
                    ),
                    if (_isOnline && _case != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'You have an active emergency. Finish handover before going Offline.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _loadingCase
                              ? 'CHECKING DISPATCH…'
                              : _case == null
                              ? 'NO ACTIVE EMERGENCY'
                              : 'ACTIVE TRIP ${_case?['code'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _loadingCase
                                ? 'SYNCING'
                                : _case == null
                                ? _serverUnavailable
                                      ? 'CONNECTION LOST'
                                      : 'WAITING FOR DISPATCH'
                                : _stageLabel('${_case?['status']}')
                                      .toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Patient Pickup Location:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _case == null
                          ? 'No emergency assigned'
                          : '${_case?['lat'] ?? ''}, ${_case?['lng'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (_case != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Patient: ${_case?['patient_name'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Destination: ${_case?['hospital'] ?? 'Hospital not assigned'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isOnline && _case != null)
                            ? () {
                                _gpsTimer?.cancel();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DriverLocationScreen(
                                      patientName:
                                          '${_case?['patient_name'] ?? 'Waiting for assignment'}',
                                      pickupLocation: _case == null
                                          ? 'Awaiting dispatch'
                                          : '${_case?['lat'] ?? ''}, ${_case?['lng'] ?? ''}',
                                      hospitalDestination:
                                          '${_case?['hospital'] ?? 'Hospital not assigned'}',
                                      ambulanceId: _ambulanceId,
                                    ),
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    _loadCase();
                                    if (_isOnline)
                                      _gpsTimer = Timer.periodic(
                                        const Duration(seconds: 6),
                                        (_) => _sendLocation(requestPermission: false),
                                      );
                                  }
                                });
                              }
                            : null,
                        icon: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          _case == null
                              ? 'Waiting for an assigned emergency'
                              : 'Open Trip Navigation',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
