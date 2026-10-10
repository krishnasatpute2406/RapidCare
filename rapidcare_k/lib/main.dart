import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';       // Add import for your splash screen
import 'screens/patient/patient_dashboard.dart';
import 'screens/driver/driver_login.dart';

void main() {
  runApp(const RapidCareApp());
}

class RapidCareApp extends StatelessWidget {
  const RapidCareApp({super.key});

  @override
  Widget build(context) {
    return MaterialApp(
      title: 'RapidCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004D40)),
        useMaterial3: true,
      ),
      // Change this from PatientDashboard to SplashScreen so the app loads it first
      home: const SplashScreen(),
    );
  }
}