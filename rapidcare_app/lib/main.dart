import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/emergency_sos_screen.dart';
import 'screens/location_screen.dart';
import 'screens/emergency_type_screen.dart';
import 'screens/hospital_recommendation_screen.dart';
import 'screens/hospital_details_screen.dart';
import 'screens/hospital_discovery_screen.dart';
import 'screens/medical_records_screen.dart';
import 'screens/emergency_processing_screen.dart';
import 'screens/empty_state_screen.dart';
import 'screens/request_ambulance_screen.dart';
import 'screens/ambulance_status_screen.dart';
import 'screens/driver_login_screen.dart';
import 'screens/driver_dashboard_screen.dart';
import 'screens/trip_status_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_medical_records_screen.dart';
import 'screens/main_shell.dart';
import 'screens/history_screen.dart';
import 'screens/notifications_screen.dart';

void main() {
  runApp(const RapidCareApp());
}

class RapidCareApp extends StatelessWidget {
  const RapidCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RapidCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      // Initial route is the Splash Screen
      initialRoute: '/',
      
      routes: {
        '/': (context) => const SplashScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/emergency-sos': (context) => const EmergencySosScreen(),
        '/location-confirm': (context) => const LocationScreen(),
        '/hospital-discovery': (context) => const HospitalDiscoveryScreen(),
        '/emergency-type': (context) => const EmergencyTypeScreen(),
        '/hospital-recommendation': (context) => const HospitalRecommendationScreen(),
        '/hospital-details': (context) => const HospitalDetailsScreen(),
        '/request-ambulance': (context) => const RequestAmbulanceScreen(),
        '/ambulance-status': (context) => const AmbulanceStatusScreen(),
        '/driver-login': (context) => const DriverLoginScreen(),
        '/driver-dashboard': (context) => const DriverDashboardScreen(),
        '/trip-status': (context) => const TripStatusScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/medical-records': (context) => const MedicalRecordsScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/edit-medical': (context) => const EditMedicalRecordsScreen(),
        '/emergency-processing': (context) => const EmergencyProcessingScreen(),
        '/error-state': (context) => const EmptyStateScreen(
          title: 'No Hospitals Found',
          message: 'We could not find any medical facilities in your immediate area. Please try a wider search.',
          icon: Icons.search_off,
        ),
        '/main-shell': (context) => const MainShell(),
        '/history': (context) => const HistoryScreen(),
        '/notifications': (context) => const NotificationsScreen(),
      },
    );
  }
}

// Simple placeholder for routes not yet implemented
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Screen Placeholder')),
    );
  }
}
