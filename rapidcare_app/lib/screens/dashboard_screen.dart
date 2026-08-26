import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../data/dummy_data.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Personalized AppBar
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryBlue,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/login', arguments: '/profile'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Hello, Krishna', style: TextStyle(color: Colors.white, fontSize: 16)),
              background: Container(color: AppTheme.primaryBlue),
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SOS Section
                  const Text(
                    'Emergency SOS',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SOSButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/emergency-sos');
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Quick Actions Grid
                  const Text(
                    'Quick Services',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildActionCard(
                        context,
                        'Find Hospital',
                        Icons.local_hospital,
                        AppTheme.primaryBlue,
                        onTap: () => Navigator.pushNamed(context, '/hospital-discovery'),
                      ),
                      _buildActionCard(
                        context,
                        'Ambulance',
                        Icons.emergency,
                        AppTheme.secondaryTeal,
                        onTap: () => Navigator.pushNamed(context, '/emergency-type'),
                      ),
                      _buildActionCard(
                        context,
                        'Medical Info',
                        Icons.health_and_safety,
                        Colors.orange,
                        onTap: () => Navigator.pushNamed(context, '/login', arguments: '/medical-records'),
                      ),
                      _buildActionCard(
                        context,
                        'Driver Mode',
                        Icons.drive_eta,
                        Colors.blueGrey,
                        onTap: () => Navigator.pushNamed(context, '/driver-login'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Recent Activity Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/history'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...DummyData.history.map((request) => _buildRecentActivityItem(request)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityItem(dynamic request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.history, color: AppTheme.primaryBlue, size: 20),
        ),
        title: Text(request.emergencyType, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(DateFormat('dd MMM, hh:mm a').format(request.dateTime)),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () {},
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
