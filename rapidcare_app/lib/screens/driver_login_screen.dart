import 'package:flutter/material.dart';

class DriverLoginScreen extends StatelessWidget {
  const DriverLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Login')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ambulance Driver Portal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Enter your credentials to access the dashboard', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Driver ID / Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/driver-dashboard');
              },
              child: const Text('LOGIN AS DRIVER'),
            ),
          ],
        ),
      ),
    );
  }
}
