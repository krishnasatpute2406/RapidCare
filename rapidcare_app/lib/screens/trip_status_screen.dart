import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TripStatusScreen extends StatefulWidget {
  const TripStatusScreen({super.key});

  @override
  State<TripStatusScreen> createState() => _TripStatusScreenState();
}

class _TripStatusScreenState extends State<TripStatusScreen> {
  int currentStep = 0;

  final List<String> statuses = [
    'En Route to Patient',
    'Arrived at Patient',
    'Patient Picked Up',
    'En Route to Hospital',
    'Arrived at Hospital',
    'Completed'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Trip')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Current Status', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      statuses[currentStep],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Stepper(
                physics: const NeverScrollableScrollPhysics(),
                currentStep: currentStep,
                controlsBuilder: (context, details) => const SizedBox.shrink(),
                steps: statuses.map((status) {
                  int index = statuses.indexOf(status);
                  return Step(
                    title: Text(status),
                    isActive: currentStep >= index,
                    state: currentStep > index ? StepState.complete : StepState.indexed,
                    content: const SizedBox.shrink(),
                  );
                }).toList(),
              ),
            ),
            if (currentStep < statuses.length - 1)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentStep++;
                  });
                },
                child: Text('UPDATE TO: ${statuses[currentStep + 1]}'),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('FINISH TRIP'),
              ),
          ],
        ),
      ),
    );
  }
}
