import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'emergency/emergency_location.dart';
import 'emergency/emergency_type.dart';
import 'emergency/emergency_hospitals.dart';
import 'emergency/emergency_detail.dart';
import 'emergency/emergency_assigned.dart';

class PatientEmergency extends StatefulWidget {
  const PatientEmergency({super.key});

  @override
  State<PatientEmergency> createState() => _PatientEmergencyState();
}

class _PatientEmergencyState extends State<PatientEmergency> {
  int _currentStep = 0;

  // Emergency session data, filled in as the patient moves through the steps
  String _location = 'Locating…';
  LatLng? _position; // live GPS from step 1
  bool _manualPickup = false;
  String _emergencyType = 'Cardiac';
  String _patientName = '';
  String _patientPhone = '';
  Map<String, dynamic>? _hospital; // the hospital chosen in step 3 (id, name, lat, lng…)

  void _nextStep() => setState(() { if (_currentStep < 4) _currentStep++; });
  void _prevStep() => setState(() { if (_currentStep > 0) _currentStep--; });

  void _cancelEmergency() {
    setState(() => _currentStep = 0);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated: CANCELLED')));
  }

  @override
  Widget build(BuildContext context) {
    final hospitalName = '${_hospital?['name'] ?? ''}';
    final List<Widget> steps = [
      EmergencyLocationScreen(
        location: _location,
        onLocationChanged: (loc) => setState(() => _location = loc),
        onLatLngChanged: (p) => setState(() => _position = p),
        onManualLocationChanged: (manual) => setState(() => _manualPickup = manual),
        onNext: _nextStep,
      ),
      EmergencyTypeScreen(
        selectedType: _emergencyType,
        onTypeSelected: (type) {
          setState(() => _emergencyType = type);
          _nextStep();
        },
        onBack: _prevStep,
      ),
      EmergencyHospitalsScreen(
        key: ValueKey('$_emergencyType-${_position?.latitude}'), // reload if type or position changes
        emergencyType: _emergencyType,
        patient: _position,
        onHospitalSelected: (h) {
          setState(() => _hospital = h);
          _nextStep();
        },
        onBack: _prevStep,
      ),
      EmergencyDetailScreen(
        hospital: _hospital ?? const <String, dynamic>{},
        onRequestAmbulance: (details) {
          setState(() {
            _patientName = details['name'] ?? '';
            _patientPhone = details['phone'] ?? '';
          });
          _nextStep();
        },
        onBack: _prevStep,
      ),
      EmergencyAssignedScreen(
        hospitalName: hospitalName,
        hospitalId: _hospital?['id'] as int?,
        lat: _position?.latitude,
        lng: _position?.longitude,
        trackLiveLocation: !_manualPickup,
        emergencyType: _emergencyType,
        patientName: _patientName,
        patientPhone: _patientPhone,
        onCancel: _cancelEmergency,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(child: steps[_currentStep]),
    );
  }
}
