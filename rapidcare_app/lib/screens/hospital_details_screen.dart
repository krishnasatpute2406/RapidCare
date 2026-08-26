import 'package:flutter/material.dart';
import '../models/hospital.dart';
import '../widgets/hospital_detail_content.dart';

class HospitalDetailsScreen extends StatefulWidget {
  const HospitalDetailsScreen({super.key});

  @override
  State<HospitalDetailsScreen> createState() => _HospitalDetailsScreenState();
}

class _HospitalDetailsScreenState extends State<HospitalDetailsScreen> {
  late PageController _pageController;
  late List<Hospital> _hospitals;
  late int _currentIndex;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      
      if (args is Map<String, dynamic>) {
        _hospitals = args['hospitals'] as List<Hospital>;
        _currentIndex = args['initialIndex'] as int;
        
        _pageController = PageController(initialPage: _currentIndex);
        _isInitialized = true;
      } else {
        // Fallback for missing arguments
        _hospitals = [];
        _currentIndex = 0;
        _pageController = PageController();
        _isInitialized = true;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hospitals.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hospital Details')),
        body: const Center(child: Text('No hospital data available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_hospitals[_currentIndex].name),
      ),
      body: Column(
        children: [
          // Index Indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_hospitals.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index ? Colors.blue : Colors.grey[300],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _hospitals.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return HospitalDetailContent(hospital: _hospitals[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
