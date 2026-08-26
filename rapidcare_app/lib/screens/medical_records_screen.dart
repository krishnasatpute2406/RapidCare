import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MedicalRecordsScreen extends StatelessWidget {
  const MedicalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Health Records'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Health Summary',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Keep your medical information up to date.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            _buildHealthCategory('Vitals & Basic Info', [
              _buildHealthItem(Icons.bloodtype_outlined, 'Blood Group', 'O+ Positive', Colors.red),
              _buildHealthItem(Icons.monitor_weight_outlined, 'Weight', '76 kg', Colors.blue),
              _buildHealthItem(Icons.height, 'Height', '183 cm', Colors.green),
            ]),
            
            const SizedBox(height: 24),
            
            _buildHealthCategory('Medical Conditions', [
              _buildHealthItem(Icons.warning_amber_outlined, 'Chronic Status', 'None', Colors.orange),
              _buildHealthItem(Icons.healing_outlined, 'Recent Issues', 'Recovering from Fracture', Colors.teal),
            ]),
            
            const SizedBox(height: 24),
            
            _buildHealthCategory('Safety Information', [
              _buildHealthItem(Icons.no_food_outlined, 'Allergies', 'Peanuts, Penicillin', Colors.purple),
              _buildHealthItem(Icons.medication_outlined, 'Current Meds', 'Multivitamins', Colors.indigo),
            ]),
            
            const SizedBox(height: 40),
            
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/edit-medical'),
              icon: const Icon(Icons.edit),
              label: const Text('UPDATE MEDICAL INFO'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCategory(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildHealthItem(IconData icon, String label, String value, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
    );
  }
}
