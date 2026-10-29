import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/rapidcare_theme.dart';

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
      theme: RapidCareTheme.light,
      home: const SplashScreen(),
    );
  }
}
