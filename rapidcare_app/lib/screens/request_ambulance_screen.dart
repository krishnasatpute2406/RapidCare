import 'package:flutter/material.dart';
import '../models/hospital.dart';

class RequestAmbulanceScreen extends StatefulWidget {
  const RequestAmbulanceScreen({super.key});

  @override
  State<RequestAmbulanceScreen> createState() => _RequestAmbulanceScreenState();
}

class _RequestAmbulanceScreenState extends State<RequestAmbulanceScreen> {
  bool _isAssigned = false;

  @override
  void initState() {
    super.initState();
    // Simulate ambulance assignment delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isAssigned = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ModalRoute.of(context)!.settings.arguments as Hospital;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Ambulance Assignment'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isAssigned) ...[
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(strokeWidth: 8),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Assigning Nearest Ambulance...',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Target Hospital: ${hospital.name}', style: const TextStyle(color: Colors.grey)),
              ] else ...[
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  'Ambulance Assigned!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('John Doe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text('ID: RC-DRV-7741', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            Icon(Icons.phone, color: Colors.green),
                          ],
                        ),
                        const Divider(height: 40),
                        _buildAssignmentInfo('Ambulance', 'MH-12-AB-1234'),
                        _buildAssignmentInfo('ETA', '5 Minutes'),
                        _buildAssignmentInfo('Hospital', hospital.name),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/ambulance-status');
                  },
                  child: const Text('TRACK AMBULANCE'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
