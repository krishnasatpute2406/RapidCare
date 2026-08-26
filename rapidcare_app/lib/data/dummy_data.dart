import '../models/hospital.dart';
import '../models/emergency_request.dart';
import '../models/notification.dart';

class DummyData {
  static List<Hospital> hospitals = [
    Hospital(
      id: 'h1',
      name: 'City Care Hospital',
      distance: 2.4,
      availableBeds: 12,
      hasICU: true,
      specialists: ['Cardiology', 'Emergency Medicine'],
      etaMinutes: 8,
      rating: 4.8,
      recommendationScore: 98,
      facilities: ['Advanced ICU', '24/7 Trauma Center', 'Ventilator Support', 'Blood Bank'],
      whyRecommended: 'Shortest ETA (8 mins) and highly rated Cardiology specialists are currently on duty.',
      phone: '+91 99887 76655',
      address: '72 North View, Medical District',
    ),
    Hospital(
      id: 'h2',
      name: 'LifeLine Hospital',
      distance: 3.1,
      availableBeds: 7,
      hasICU: true,
      specialists: ['Trauma', 'Emergency Medicine'],
      etaMinutes: 11,
      rating: 4.6,
      recommendationScore: 92,
      facilities: ['Emergency Surgery', 'X-Ray & Imaging', '24/7 Pharmacy'],
      whyRecommended: 'Specialized Trauma unit with available beds and direct ambulance bay access.',
      phone: '+91 88776 65544',
      address: '45 East Ridge, Healthcare Hub',
    ),
    Hospital(
      id: 'h3',
      name: 'Metro Emergency Hospital',
      distance: 4.5,
      availableBeds: 15,
      hasICU: true,
      specialists: ['Cardiology', 'Trauma'],
      etaMinutes: 14,
      rating: 4.2,
      recommendationScore: 85,
      facilities: ['Pediatric Emergency', 'Burn Unit', 'Ambulance Fleet'],
      whyRecommended: 'Large capacity with 15 available beds and a dedicated Burn unit if needed.',
      phone: '+91 77665 54433',
      address: '12 Central Square, Metro Park',
    ),
  ];

  static List<Map<String, dynamic>> emergencyTypes = [
    {'name': 'Accident', 'icon': 'emergency'},
    {'name': 'Cardiac', 'icon': 'favorite'},
    {'name': 'Trauma', 'icon': 'healing'},
    {'name': 'Burn', 'icon': 'whatshot'},
    {'name': 'Pregnancy', 'icon': 'child_care'},
    {'name': 'Other', 'icon': 'help_outline'},
  ];

  static List<EmergencyRequest> history = [
    EmergencyRequest(
      id: 'REQ-101',
      patientLocation: '123, RapidCare Lane',
      emergencyType: 'Cardiac Emergency',
      targetHospital: hospitals[0],
      status: RequestStatus.completed,
      dateTime: DateTime.now().subtract(const Duration(days: 2)),
    ),
    EmergencyRequest(
      id: 'REQ-102',
      patientLocation: 'Metro Station Area',
      emergencyType: 'Accident',
      targetHospital: hospitals[1],
      status: RequestStatus.cancelled,
      dateTime: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  static List<AppNotification> notifications = [
    AppNotification(
      id: 'n1',
      title: 'Emergency Completed',
      body: 'Your request REQ-101 has been marked as completed. Thank you for using RapidCare.',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      type: NotificationType.success,
      isRead: true,
    ),
    AppNotification(
      id: 'n2',
      title: 'Ambulance Dispatched',
      body: 'Ambulance MH-12-AB-1234 is en route to your location.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.emergency,
    ),
    AppNotification(
      id: 'n3',
      title: 'New Feature Available',
      body: 'You can now view your medical history directly from the dashboard.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      type: NotificationType.info,
    ),
  ];
}
