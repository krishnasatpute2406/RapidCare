import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/dummy_data.dart';
import '../models/notification.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: DummyData.notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: DummyData.notifications.length,
              itemBuilder: (context, index) {
                final notification = DummyData.notifications[index];
                return _buildNotificationCard(notification);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No Notifications', style: TextStyle(fontSize: 20, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.emergency:
        icon = Icons.emergency;
        iconColor = AppTheme.emergencyRed;
        break;
      case NotificationType.success:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case NotificationType.warning:
        icon = Icons.warning;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.info;
        iconColor = AppTheme.primaryBlue;
    }

    return Card(
      color: notification.isRead ? Colors.white : Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 8),
            Text(
              DateFormat('hh:mm a, dd MMM').format(notification.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
