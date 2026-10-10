import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'driver_dashboard.dart';
import '../../services/api.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _licenseController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;

  Future<void> _handleRegistration() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }
    if (_phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }
    if (_vehicleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your vehicle registration number')),
      );
      return;
    }
    if (_licenseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your driving license number')),
      );
      return;
    }
    if (_pinController.text.length < 6 || _pinController.text.length > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a numeric PIN with 6–12 digits')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await api('/api/driver/register', method: 'POST', body: {
        'driver': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicle_number': _vehicleController.text.trim(),
        'license_number': _licenseController.text.trim(),
        'pin': _pinController.text,
      });
      if (!mounted) return;
      setApiToken(result['token']?.toString());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DriverDashboard(driver: Map<String, dynamic>.from(result['driver']))),
      );
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00695C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New Driver Registration',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'RapidCare Emergency Fleet (Malad & Goregaon)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person, size: 18),
                          hintText: 'Enter full name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone, size: 18),
                          prefixText: '+91 ',
                          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          hintText: 'Enter 10-digit number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Ambulance / Vehicle Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _vehicleController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.local_shipping, size: 18),
                          hintText: 'e.g. MH 02 AB 1234',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Driving License Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _licenseController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.card_membership, size: 18),
                          hintText: 'Enter license number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Create Secure PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                          hintText: 'Create a 6–12 digit PIN',
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Register & Start Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Login here',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
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
          ),
        ),
      ),
    );
  }
}
