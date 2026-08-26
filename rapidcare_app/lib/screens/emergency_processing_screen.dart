import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmergencyProcessingScreen extends StatefulWidget {
  const EmergencyProcessingScreen({super.key});

  @override
  State<EmergencyProcessingScreen> createState() => _EmergencyProcessingScreenState();
}

class _EmergencyProcessingScreenState extends State<EmergencyProcessingScreen> {
  int _currentStep = 0;
  final List<String> _steps = [
    'Location detected',
    'Emergency type identified',
    'Searching nearby hospitals...',
    'Checking ambulance availability...',
    'Generating recommendations...'
  ];

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  void _startProcessing() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() {
          _currentStep = i + 1;
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/hospital-recommendation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.analytics, size: 64, color: AppTheme.primaryBlue),
            const SizedBox(height: 24),
            const Text(
              'Processing Emergency',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Finding the fastest medical assistance for you.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 48),
            ...List.generate(_steps.length, (index) {
              bool isDone = index < _currentStep;
              bool isCurrent = index == _currentStep;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    isDone 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : isCurrent 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                    const SizedBox(width: 16),
                    Text(
                      _steps[index],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isDone ? Colors.black : isCurrent ? AppTheme.primaryBlue : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
