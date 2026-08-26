import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool isOnline = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('RapidCare Driver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Online Toggle Header
          Container(
            padding: const EdgeInsets.all(20),
            color: isOnline ? Colors.green[50] : Colors.blueGrey[50],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Officer: John Doe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(isOnline ? 'Online - Receiving Requests' : 'Offline - Not Visible', 
                           style: TextStyle(color: isOnline ? Colors.green : Colors.blueGrey)),
                    ],
                  ),
                ),
                Switch(
                  value: isOnline,
                  activeThumbColor: Colors.green,
                  onChanged: (v) => setState(() => isOnline = v),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Active Emergency Requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          
          if (!isOnline)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_off, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Go online to view emergencies nearby', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildEmergencyCard(
                    context,
                    'REQ-2024-88',
                    'Cardiac Emergency',
                    '2.4 km away',
                    '123 Emergency St, Healthcare City',
                    'City Care Hospital',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context, String id, String type, String dist, String loc, String hospital) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.emergencyRed, width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.emergencyRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(type, style: const TextStyle(color: AppTheme.emergencyRed, fontWeight: FontWeight.bold)),
                ),
                Text(dist, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Patient Location:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text(loc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Recommended Target:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text(hospital, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            
            // Slide to Accept Simulation
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(30),
              ),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/trip-status'),
                borderRadius: BorderRadius.circular(30),
                child: const Stack(
                  children: [
                    Center(child: Text('TAP TO ACCEPT EMERGENCY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    Positioned(
                      left: 4,
                      top: 4,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.chevron_right, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
