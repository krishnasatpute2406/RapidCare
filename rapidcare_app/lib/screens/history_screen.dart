import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/emergency_request.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency History'),
      ),
      body: DummyData.history.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: DummyData.history.length,
              itemBuilder: (context, index) {
                final request = DummyData.history[index];
                return _buildHistoryCard(context, request);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.blueGrey[200]),
          const SizedBox(height: 24),
          const Text(
            'No Emergency History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          const Text('Your past emergency requests will appear here.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, EmergencyRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case RequestStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case RequestStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showHistoryDetails(context, request),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    request.emergencyType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          request.status.name.toUpperCase(),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(request.dateTime),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_hospital, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    request.targetHospital.name,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetails(BuildContext context, EmergencyRequest request) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.emergencyType, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(DateFormat('MMMM dd, yyyy • hh:mm a').format(request.dateTime), style: const TextStyle(color: Colors.grey)),
              const Divider(height: 40),
              _buildDetailItem('Hospital', request.targetHospital.name),
              _buildDetailItem('Location', request.patientLocation),
              _buildDetailItem('Request ID', request.id),
              _buildDetailItem('Status', request.status.name.toUpperCase()),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
