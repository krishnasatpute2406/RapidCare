import 'package:flutter/material.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Section matching dashboard theme
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
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
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.location_on, color: Color(0xFF4DB6AC), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Device location is read when you use Emergency or Hospitals',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Emergency Medical Card Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Medical Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004D40),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accessible by paramedics during dispatch',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    // Medical Card Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Blood Group & Organ Donor Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'BLOOD GROUP',
                                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'O Rh-Positive (O+)',
                                    style: TextStyle(color: Color(0xFFD32F2F), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: const [
                                  Text(
                                    'ORGAN DONOR',
                                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Registered (Yes)',
                                    style: TextStyle(color: Color(0xFF00796B), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.0),
                            child: Divider(color: Colors.grey, height: 1),
                          ),

                          // Known Medical Conditions
                          const Text(
                            'KNOWN MEDICAL CONDITIONS',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mild Hypertension, No Diabetes',
                            style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),

                          // Allergies
                          const Text(
                            'ALLERGIES',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Penicillin / Sulfa Drugs',
                            style: TextStyle(color: Color(0xFFD32F2F), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.0),
                            child: Divider(color: Colors.grey, height: 1),
                          ),

                          // Primary Emergency Contact
                          const Text(
                            'PRIMARY EMERGENCY CONTACT',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pooja Sharma (Spouse)',
                            style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '+91  98200  99887',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
