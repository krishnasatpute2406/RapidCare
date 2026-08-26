import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLocationDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Simulate location detection delay and auto-navigate
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLocationDetected = true;
        });
        
        // Auto-navigate after a brief success pause
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/location-confirm');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.emergencyRed,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('EMERGENCY SOS'),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3 * _controller.value),
                          blurRadius: 40 * _controller.value,
                          spreadRadius: 20 * _controller.value,
                        ),
                      ],
                    ),
                    child: ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.3).animate(
                        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 100,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                _isLocationDetected ? 'Location Confirmed' : 'Detecting Your Location...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isLocationDetected 
                  ? 'Current Address: 123 Emergency St, Healthcare City' 
                  : 'We are identifying your exact coordinates for the rescue team.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 60),
              
              if (_isLocationDetected)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/location-confirm');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.emergencyRed,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('PROCEED TO CONFIRM'),
                )
              else
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              
              const SizedBox(height: 40),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel Request',
                  style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
