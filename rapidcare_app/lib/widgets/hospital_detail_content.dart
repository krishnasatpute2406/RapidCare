import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/hospital.dart';

class HospitalDetailContent extends StatelessWidget {
  final Hospital hospital;

  const HospitalDetailContent({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image Placeholder
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.blueGrey[100],
            child: const Icon(Icons.business, size: 100, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospital.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text('${hospital.rating} Rating', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Text('${hospital.distance} km away', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.emergencyRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${hospital.etaMinutes} MIN ETA',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildActionButton(context, Icons.phone, 'CALL HOSPITAL', Colors.green, () {
                      _showContactOptions(context);
                    }),
                  ],
                ),
                const Divider(height: 48),
                
                const Text('Facility Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.bed, 'Available Beds', hospital.availableBeds.toString()),
                _buildDetailRow(Icons.medical_services, 'ICU Service', hospital.hasICU ? 'Available' : 'Unavailable'),
                _buildDetailRow(Icons.emergency, 'Emergency Unit', 'Open 24/7'),
                
                const SizedBox(height: 24),
                const Text('Key Facilities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hospital.facilities.map((fac) => Chip(
                    label: Text(fac, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey[100],
                  )).toList(),
                ),

                const SizedBox(height: 24),
                const Text('Specialists on Duty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hospital.specialists.map((spec) => Chip(
                    label: Text(spec),
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  )).toList(),
                ),
                
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => _confirmHospitalSelection(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                  child: const Text('SELECT THIS HOSPITAL'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: color.withOpacity(0.2))),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black87)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showContactOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, size: 40, color: Colors.green),
              ),
              const SizedBox(height: 24),
              const Text(
                'Contact Hospital',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Direct line to ${hospital.name}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hospital.phone,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: hospital.phone));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Phone number copied: ${hospital.phone}'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('COPY NUMBER'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmHospitalSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline, size: 64, color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              const Text(
                'Confirm Hospital',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Do you want to proceed with ${hospital.name}?\nAn ambulance will be requested immediately.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('GO BACK'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close sheet
                        Navigator.pushNamed(
                          context,
                          '/request-ambulance',
                          arguments: hospital,
                        );
                      },
                      child: const Text('PROCEED'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
