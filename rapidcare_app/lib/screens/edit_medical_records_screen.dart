import 'package:flutter/material.dart';

class EditMedicalRecordsScreen extends StatelessWidget {
  const EditMedicalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Medical Info')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: 'O+ Positive'),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: '76'),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: '183'),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Medical Conditions / History',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: 'None'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Medical Records Updated!')),
                );
                Navigator.pop(context);
              },
              child: const Text('SAVE MEDICAL INFO'),
            ),
          ],
        ),
      ),
    );
  }
}
