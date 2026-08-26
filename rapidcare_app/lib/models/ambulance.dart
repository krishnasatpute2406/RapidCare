enum AmbulanceStatus { available, enRouteToPatient, arrivedAtPatient, pickedUp, enRouteToHospital, completed }

class Ambulance {
  final String id;
  final String plateNumber;
  final String driverName;
  final AmbulanceStatus status;

  Ambulance({
    required this.id,
    required this.plateNumber,
    required this.driverName,
    this.status = AmbulanceStatus.available,
  });
}
