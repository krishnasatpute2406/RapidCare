import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/dummy_data.dart';

class EmergencyTypeScreen extends StatelessWidget {
  const EmergencyTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Type of Emergency')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What is the nature of the emergency?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: DummyData.emergencyTypes.length,
                itemBuilder: (context, index) {
                  final type = DummyData.emergencyTypes[index];
                  return Card(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/emergency-processing'),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getIconData(type['icon']),
                              size: 50,
                              color: AppTheme.emergencyRed,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              type['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'emergency': return Icons.emergency;
      case 'favorite': return Icons.favorite;
      case 'healing': return Icons.healing;
      case 'whatshot': return Icons.whatshot;
      case 'child_care': return Icons.child_care;
      default: return Icons.help_outline;
    }
  }
}
