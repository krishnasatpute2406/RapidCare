import 'package:flutter/material.dart';

class EmergencyTypeScreen extends StatefulWidget {
  final String selectedType;
  final Function(String) onTypeSelected;
  final VoidCallback onBack;

  const EmergencyTypeScreen({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.onBack,
  });

  @override
  State<EmergencyTypeScreen> createState() => _EmergencyTypeScreenState();
}

class _EmergencyTypeScreenState extends State<EmergencyTypeScreen>
    with SingleTickerProviderStateMixin {
  late String _currentSelected;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _currentSelected = widget.selectedType;
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Bar Header carried forward from Emergency Location Screen
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
                    'Step 2 of 5',
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
                  'Exit',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // Compact Scrollable Body to avoid looking empty or oversized
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Emergency Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Critical: Filters hospital capabilities and specialist availability',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45, // Compact card ratio so it doesn't stretch too much
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    buildEmergencyCard(
                      icon: Icons.favorite,
                      title: 'Cardiac',
                      subtitle: 'Heart attack, chest pain',
                      isSelected: _currentSelected == 'Cardiac',
                      onTap: () {
                        setState(() => _currentSelected = 'Cardiac');
                        widget.onTypeSelected('Cardiac');
                      },
                    ),
                    buildEmergencyCard(
                      icon: Icons.warning_amber_rounded,
                      title: 'Accident',
                      subtitle: 'Road collision, fall',
                      isSelected: _currentSelected == 'Accident',
                      onTap: () {
                        setState(() => _currentSelected = 'Accident');
                        widget.onTypeSelected('Accident');
                      },
                    ),
                    buildEmergencyCard(
                      icon: Icons.medical_services,
                      title: 'Trauma',
                      subtitle: 'Severe fracture, injury',
                      isSelected: _currentSelected == 'Trauma',
                      onTap: () {
                        setState(() => _currentSelected = 'Trauma');
                        widget.onTypeSelected('Trauma');
                      },
                    ),
                    buildEmergencyCard(
                      icon: Icons.local_fire_department,
                      title: 'Burn',
                      subtitle: 'Fire, chemical burn',
                      isSelected: _currentSelected == 'Burn',
                      onTap: () {
                        setState(() => _currentSelected = 'Burn');
                        widget.onTypeSelected('Burn');
                      },
                    ),
                    buildEmergencyCard(
                      icon: Icons.pregnant_woman,
                      title: 'Pregnancy',
                      subtitle: 'Labor, maternity',
                      isSelected: _currentSelected == 'Pregnancy',
                      onTap: () {
                        setState(() => _currentSelected = 'Pregnancy');
                        widget.onTypeSelected('Pregnancy');
                      },
                    ),
                    buildEmergencyCard(
                      icon: Icons.monitor_heart,
                      title: 'Other',
                      subtitle: 'Respiratory, stroke, fever',
                      isSelected: _currentSelected == 'Other',
                      onTap: () {
                        setState(() => _currentSelected = 'Other');
                        widget.onTypeSelected('Other');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildEmergencyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFD32F2F),
                    size: 16.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}