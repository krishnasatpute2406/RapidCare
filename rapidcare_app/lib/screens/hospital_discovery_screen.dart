import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/dummy_data.dart';

class HospitalDiscoveryScreen extends StatelessWidget {
  const HospitalDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Hospital'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search hospitals, specialists...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Open 24/7', true),
                _buildFilterChip('Has ICU', false),
                _buildFilterChip('Near Me', false),
                _buildFilterChip('Top Rated', false),
              ],
            ),
          ),
          
          // Simulated Map / List View
          Expanded(
            child: Stack(
              children: [
                // Simulated Map Background
                Container(
                  color: Colors.blueGrey[50],
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.1))),
                    ),
                  ),
                ),
                
                // Simulated Hospital Markers
                const Positioned(top: 100, left: 150, child: Icon(Icons.local_hospital, color: Colors.blue, size: 30)),
                const Positioned(top: 250, left: 80, child: Icon(Icons.local_hospital, color: Colors.blue, size: 30)),
                const Positioned(top: 180, right: 100, child: Icon(Icons.local_hospital, color: Colors.blue, size: 30)),
                
                // Bottom List Sheet (Static Peek)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 280,
                    padding: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text('Nearby Hospitals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: DummyData.hospitals.length,
                            itemBuilder: (context, index) {
                              final hospital = DummyData.hospitals[index];
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.business)),
                                title: Text(hospital.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${hospital.distance} km • ${hospital.etaMinutes} min away'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pushNamed(
                                  context, 
                                  '/hospital-details',
                                  arguments: {
                                    'hospitals': DummyData.hospitals,
                                    'initialIndex': index,
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) {},
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryBlue.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
