import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Location')),
      body: Column(
        children: [
          // Professional Map Simulation
          Expanded(
            child: Stack(
              children: [
                // Grid Background
                Container(
                  color: Colors.blueGrey[50],
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.1))),
                    ),
                  ),
                ),
                
                // Pulsing Current Location Dot
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60 * _pulseController.value,
                            height: 60 * _pulseController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.3 * (1 - _pulseController.value)),
                            ),
                          ),
                          const Icon(Icons.my_location, color: Colors.blue, size: 30),
                        ],
                      );
                    },
                  ),
                ),

                // Top Floating Search Simulation
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('123 Emergency St, Healthcare City', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Confirmation Panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.emergencyRed.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.location_on, color: AppTheme.emergencyRed),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pick-up Location', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('123 Emergency St, Healthcare City', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('EDIT')),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/emergency-type'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                  child: const Text('CONFIRM & CONTINUE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
