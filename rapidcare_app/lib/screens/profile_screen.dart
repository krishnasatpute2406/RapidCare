import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('Krishna', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Member since 2024', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildInfoCard('Contact Information', [
              _buildInfoRow(Icons.phone_outlined, 'Phone', '+91 9876543210'),
              _buildInfoRow(Icons.email_outlined, 'Email', 'krishna@example.com'),
              _buildInfoRow(Icons.location_on_outlined, 'Address', '123, RapidCare Lane, City'),
            ]),
            
            const SizedBox(height: 24),
            
            _buildInfoCard('App Settings', [
              _buildInfoRow(Icons.notifications_none, 'Notifications', 'Enabled'),
              _buildInfoRow(Icons.security_outlined, 'Privacy & Security', ''),
              _buildInfoRow(Icons.help_outline, 'Help & Support', ''),
            ]),
            
            const SizedBox(height: 40),
            
            TextButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('LOGOUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: value.isNotEmpty ? Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)) : null,
      trailing: const Icon(Icons.chevron_right, size: 18),
    );
  }
}
