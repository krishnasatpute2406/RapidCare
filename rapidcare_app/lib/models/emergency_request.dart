import 'hospital.dart';
import 'ambulance.dart';

enum RequestStatus { pending, accepted, inProgress, completed, cancelled }

class EmergencyRequest {
  final String id;
  final String patientLocation;
  final String emergencyType;
  final Hospital targetHospital;
  final Ambulance? assignedAmbulance;
  final RequestStatus status;
  final DateTime dateTime;

  EmergencyRequest({
    required this.id,
    required this.patientLocation,
    required this.emergencyType,
    required this.targetHospital,
    required this.dateTime,
    this.assignedAmbulance,
    this.status = RequestStatus.pending,
  });
}
