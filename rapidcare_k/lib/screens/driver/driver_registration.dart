import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api.dart';
import '../../theme/rapidcare_theme.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = Map<String, dynamic>.from(await api(
        '/api/driver/register',
        method: 'POST',
        body: {
          'driver': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'pin': _pinController.text,
        },
      ));
      if (!mounted) return;

      setApiToken(null);
      final message = result['message']?.toString() ??
          'No vehicle or license number is needed from you. An administrator handles verification and assignment before approving access.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: RapidCareTheme.brandTeal, size: 19),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD5DEDB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: RapidCareTheme.brandTeal, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidCareTheme.canvas,
      appBar: AppBar(
        title: const Text('Driver registration'),
        leading: IconButton(
          tooltip: 'Back to driver sign-in',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request driver access',
                style: TextStyle(
                  color: RapidCareTheme.brandDarkTeal,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Three quick details. Sign in after an administrator approves your request.',
                style: TextStyle(color: Color(0xFF596963), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F3F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC8E0D9)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: RapidCareTheme.brandTeal, size: 19),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'No vehicle or license number is needed from you. An administrator handles verification and assignment before approving access.',
                        style: TextStyle(color: RapidCareTheme.brandDarkTeal, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RapidCareTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E7E4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration('Full name', Icons.person_outline),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _fieldDecoration('10-digit phone number', Icons.phone_outlined)
                            .copyWith(prefixText: '+91 '),
                        validator: (value) => value == null || value.trim().length != 10
                            ? 'Enter a 10-digit phone number'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: _pinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: _fieldDecoration('Create a 6–12 digit PIN', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                            onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? 'Use a PIN with at least 6 digits'
                            : null,
                        onFieldSubmitted: (_) => _handleRegistration(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleRegistration,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Submit for approval'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
