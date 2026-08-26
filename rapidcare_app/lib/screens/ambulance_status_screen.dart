import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AmbulanceStatusScreen extends StatefulWidget {
  const AmbulanceStatusScreen({super.key});

  @override
  State<AmbulanceStatusScreen> createState() => _AmbulanceStatusScreenState();
}

class _AmbulanceStatusScreenState extends State<AmbulanceStatusScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _currentStep = 2; // Start at "En Route to Patient"

  final List<String> _statuses = [
    'Request Accepted',
    'Ambulance Assigned',
    'En Route to Patient',
    'Arrived at Location',
    'Patient Picked Up',
    'Hospital Reached',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _simulateProgress();
  }

  void _simulateProgress() async {
    // Progress through the remaining steps every 4 seconds
    for (int i = 3; i < _statuses.length; i++) {
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          _currentStep = i;
        });
        
        // Stop animation if ambulance arrived or trip finished
        if (i == 3 || i == 5) {
          _animationController.stop();
        } else if (i == 4) {
          // Re-start animation for movement to hospital
          _animationController.repeat();
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Simulated Animated Map Area
          Container(
            height: 300,
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueGrey[100]!),
            ),
            child: Stack(
              children: [
                // Patient Marker
                const Positioned(
                  bottom: 40,
                  right: 40,
                  child: Column(
                    children: [
                      Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                      Text('YOU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Hospital Marker
                const Positioned(
                  top: 40,
                  left: 40,
                  child: Column(
                    children: [
                      Icon(Icons.local_hospital, color: AppTheme.emergencyRed, size: 40),
                      Text('HOSPITAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Animated Ambulance Marker
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    double progress = _animationController.value;
                    
                    // Logic to show ambulance at different points based on status
                    double top = 40;
                    double left = 40;
                    
                    if (_currentStep < 3) {
                      // Moving towards Patient
                      top = 40 + (220 * progress);
                      left = 40 + (220 * progress);
                    } else if (_currentStep == 3) {
                      // Arrived at Patient
                      top = 260;
                      left = 260;
                    } else if (_currentStep == 4) {
                      // Picked up, moving to Hospital
                      top = 260 - (220 * progress);
                      left = 260 - (220 * progress);
                    } else {
                      // At Hospital
                      top = 40;
                      left = 40;
                    }

                    return Positioned(
                      top: top,
                      left: left,
                      child: const Icon(Icons.emergency, color: Colors.green, size: 36),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Current Status Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              color: AppTheme.primaryBlue,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            _statuses[_currentStep],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Status Timeline
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                return _buildTimelineItem(
                  _statuses[index], 
                  index <= _currentStep, 
                  isCurrent: index == _currentStep
                );
              },
            ),
          ),
          
          // Driver Info Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: AppTheme.secondaryTeal, child: Icon(Icons.drive_eta, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Ambulance #1234', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _currentStep < 4 ? 'Moving to your location' : 'Transporting to hospital', 
                        style: const TextStyle(color: Colors.grey, fontSize: 12)
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.call, color: Colors.green),
                  style: IconButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, bool isDone, {bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCurrent ? AppTheme.primaryBlue : isDone ? Colors.green : Colors.grey[300],
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? AppTheme.primaryBlue : isDone ? Colors.black : Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
