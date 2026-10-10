import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'driver_dashboard.dart';
import 'driver_registration.dart'; // Import your new registration screen
import '../../services/api.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;

  Future<void> _handleLogin() async {
    if (_phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await api('/api/driver/login', method: 'POST', body: {
        'phone': _phoneController.text.trim(),
        'pin': _pinController.text,
      });
      if (!mounted) return;
      setApiToken(result['token']?.toString());
      final driver = Map<String, dynamic>.from(result['driver']);
      driver['token'] = result['token'];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DriverDashboard(driver: driver)),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7F6),
        foregroundColor: const Color(0xFF004D40),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back to patient dashboard',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Driver Portal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
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
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RapidCare Driver Portal',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Emergency Fleet & Dispatch Unit (Malad & Goregaon)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 32),
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
                      const Text('Driver Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
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
                      const Text('Secure PIN / Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                          hintText: 'Enter PIN',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Login to Driver Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Not registered yet? ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            GestureDetector(
                              onTap: () {
                                // Integrated navigation to the Driver Registration screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DriverRegistrationScreen()),
                                );
                              },
                              child: const Text(
                                'Register here',
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
