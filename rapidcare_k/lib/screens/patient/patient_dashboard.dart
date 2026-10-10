import 'dart:async';
import 'package:flutter/material.dart';
import 'patient_emergency.dart';
import 'hospital_screen.dart';
import '../driver/driver_login.dart';
import 'profile_screen.dart';
import '../../services/location.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;
  bool _profileDialogOpen = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const PatientHomeTabContent(),
      const HospitalScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.warning_rounded,
                label: 'Emergency',
                activeColor: const Color(0xFFD32F2F),
                alwaysRedIcon: true,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.local_hospital_outlined,
                label: 'Hospitals',
                activeColor: const Color(0xFF00796B),
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline,
                label: 'Profile',
                activeColor: const Color(0xFF00796B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    bool alwaysRedIcon = false,
  }) {
    final isSelected = index == 2 ? _profileDialogOpen : _currentIndex == index;
    final iconColor = alwaysRedIcon
        ? const Color(0xFFD32F2F)
        : (isSelected ? activeColor : Colors.grey.shade600);
    final textColor = isSelected ? activeColor : Colors.grey.shade600;

    return InkWell(
      onTap: () async {
        if (index == 2) {
          setState(() => _profileDialogOpen = true);
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.93,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: const ProfileScreen(),
              ),
            ),
          );
          if (mounted) setState(() => _profileDialogOpen = false);
          return;
        }
        setState(() => _currentIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientHomeTabContent extends StatefulWidget {
  const PatientHomeTabContent({super.key});

  @override
  State<PatientHomeTabContent> createState() => _PatientHomeTabContentState();
}

class _PatientHomeTabContentState extends State<PatientHomeTabContent> with SingleTickerProviderStateMixin {
  // Drives the pulsing ring around the Emergency button (same loop as the animation video).
  late final AnimationController _pulse;

  // Local settings state (placeholders until they are wired to real preferences).
  bool _notifications = true;
  bool _shareLocation = true;
  bool _locationBusy = false;
  String _locationLabel = 'Finding device location…';
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _refreshLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshLocation());
  }

  Future<void> _refreshLocation() async {
    if (_locationBusy || !_shareLocation) return;
    _locationBusy = true;
    if (mounted) setState(() => _locationLabel = 'Updating live location…');
    try {
      final position = await getFreshLocation();
      if (!mounted) return;
      setState(() => _locationLabel = 'Live GPS · ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} · ±${position.accuracy.round()} m');
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationLabel = e.toString().replaceFirst('Exception: ', 'Location unavailable: '));
    } finally {
      _locationBusy = false;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _locationTimer?.cancel();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Settings',
                  style: TextStyle(color: Color(0xFF004D40), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00796B),
                  title: const Text('Emergency notifications', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Ambulance and hospital status updates', style: TextStyle(fontSize: 11)),
                  value: _notifications,
                  onChanged: (v) {
                    setSheet(() => _notifications = v);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00796B),
                  title: const Text('Share live location', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Used to find nearby hospitals and ambulances', style: TextStyle(fontSize: 11)),
                  value: _shareLocation,
                  onChanged: (v) {
                    setSheet(() => _shareLocation = v);
                    setState(() => _locationLabel = v ? 'Updating live location…' : 'Location sharing is off');
                    if (v) _refreshLocation();
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline, color: Color(0xFF00796B)),
                  title: const Text('About RapidCare', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Smart Emergency Healthcare Platform', style: TextStyle(fontSize: 11)),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'RapidCare',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF004D40),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hello,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DriverLoginScreen()),
                            );
                          },
                          icon: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
                          label: const Text('Driver Portal', style: TextStyle(color: Colors.white, fontSize: 11)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.15),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: IconButton(
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                            onPressed: _openSettings,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'How can we help you today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on, color: Color(0xFF4DB6AC), size: 16),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: Text(_locationLabel, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(width: 30, height: 30, child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Refresh live location',
                      onPressed: _locationBusy ? null : _refreshLocation,
                      icon: Icon(_locationBusy ? Icons.more_horiz : Icons.refresh, color: Colors.white70, size: 17),
                    )),
                  ]),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pulsing ring: grows outward from the button's edge and fades, then repeats.
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = Curves.easeOut.transform(_pulse.value);
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD32F2F).withOpacity(0.32 * (1 - t)),
                            spreadRadius: 14 * t,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PatientEmergency()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'EMERGENCY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Get immediate help & ambulance',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Average dispatch: 6-8 mins',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFB2DFDB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Cardiac First Response Tip',
                        style: TextStyle(
                          color: Color(0xFF004D40),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'In suspected heart attack, keep the patient calm in a seated position. Do not give water or heavy food. Request ALS ambulance immediately.',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
