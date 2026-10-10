import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class EmergencyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hospital;
  final ValueChanged<Map<String, String>> onRequestAmbulance;
  final VoidCallback onBack;

  const EmergencyDetailScreen({
    super.key,
    required this.hospital,
    required this.onRequestAmbulance,
    required this.onBack,
  });

  @override
  State<EmergencyDetailScreen> createState() => _EmergencyDetailScreenState();
}

class _EmergencyDetailScreenState extends State<EmergencyDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Function to launch phone dialer
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch phone dialer for $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalName = '${widget.hospital['name'] ?? 'Hospital'}';
    final location = '${widget.hospital['location'] ?? 'Address unavailable'}';
    final phone = '${widget.hospital['phone'] ?? ''}'.trim();
    final generalBeds = widget.hospital['available_beds']?.toString() ?? '—';
    final icuBeds = widget.hospital['icu_beds']?.toString() ?? '—';
    final specialists = (widget.hospital['specialists'] as Map?)?.cast<String, dynamic>()
        ?? const <String, dynamic>{};
    final facilities = (widget.hospital['facilities'] as Map?)?.cast<String, dynamic>()
        ?? const <String, dynamic>{};
    final availableSpecialists = specialists.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
    final availableFacilities = facilities.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
    return Column(
      children: [
        // App Bar Header matching previous steps with pulsing dot and Step 4 of 5
        Container(
          color: const Color(0xFFD32F2F),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _dotController,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'EMERGENCY ASSISTANCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Step 4 of 5',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospitalName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Text(
                      'Hospital location comes from the shared directory. Call the hospital to confirm current services and capacity.',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Patient contact details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Patient name', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    decoration: const InputDecoration(labelText: '10-digit phone number', prefixText: '+91 ', border: OutlineInputBorder(), isDense: true),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoBox('Emergency', 'ACTIVE', Colors.red),
                      _infoBox('Beds', generalBeds, Colors.black87),
                      _infoBox('ICU', icuBeds, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SPECIALISTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableSpecialists
                        .map((s) => Chip(
                      label: Text(s,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.blue.shade50,
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FACILITIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableFacilities
                        .map((f) => Chip(
                      label: Text(f,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.red.shade50,
                    ))
                        .toList(),
                  ),
                  const Divider(height: 24),
                  if (phone.isNotEmpty) Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hospital phone',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(phone,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _makePhoneCall(phone),
                        icon: const Icon(Icons.call,
                            color: Colors.white, size: 14),
                        label: const Text('Call',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final phone = _phoneController.text.trim();
                if (name.isEmpty || phone.length != 10) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the patient name and a valid 10-digit phone number.')));
                  return;
                }
                widget.onRequestAmbulance({'name': name, 'phone': phone});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'SELECT HOSPITAL & REQUEST AMBULANCE',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoBox(String title, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: valColor)),
      ],
    );
  }
}
