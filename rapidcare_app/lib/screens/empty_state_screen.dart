import 'package:flutter/material.dart';

class EmptyStateScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const EmptyStateScreen({
    super.key, 
    required this.title, 
    required this.message, 
    required this.icon
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: Colors.blueGrey[200]),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('RETRY ACTION'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
