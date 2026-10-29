import 'package:flutter/material.dart';

import '../../services/api.dart';

/// Current in-memory patient account; emergency access does not depend on it.
class PatientSession {
  static Map<String, dynamic>? currentUser;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _createAccount = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _user = PatientSession.currentUser;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final registering = _createAccount;
      final result = Map<String, dynamic>.from(await api(
        registering ? '/api/patient/register' : '/api/patient/login',
        method: 'POST',
        body: {
          if (registering) 'name': _nameController.text.trim(),
          if (registering) 'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      ));
      final token = result['token']?.toString();
      if (token == null || token.isEmpty || result['user'] is! Map) {
        throw Exception('The server did not return a patient session.');
      }
      setApiToken(token);
      final signedInUser = Map<String, dynamic>.from(result['user'] as Map);
      PatientSession.currentUser = signedInUser;
      if (!mounted) return;
      setState(() => _user = signedInUser);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signOut() {
    setApiToken(null);
    PatientSession.currentUser = null;
    setState(() {
      _user = null;
      _passwordController.clear();
      _error = null;
    });
  }

  void _toggleMode() {
    setState(() {
      _createAccount = !_createAccount;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 24,
              ),
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
                      const Icon(Icons.account_circle_outlined,
                          color: Color(0xFF80CBC4), size: 32),
                      IconButton(
                        tooltip: 'Close profile',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user == null ? 'Patient Profile' : 'Hello, ${user['name']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    user == null
                        ? 'Sign in to view your profile. Emergency help is available without an account.'
                        : 'Your RapidCare patient account',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: user == null ? _buildAuthCard() : _buildProfileCard(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _createAccount ? 'Create your account' : 'Sign in',
              style: const TextStyle(
                color: Color(0xFF004D40),
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_createAccount) ...[
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _decoration('Full name', Icons.person_outline),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _decoration('10-digit phone number', Icons.phone_outlined)
                    .copyWith(prefixText: '+91 '),
                validator: (value) => value == null ||
                        value.replaceAll(RegExp(r'\D'), '').length != 10
                    ? 'Enter a 10-digit phone number'
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: _decoration('Email address', Icons.email_outlined),
              validator: (value) => value == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              decoration: _decoration('Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_createAccount ? Icons.person_add_alt_1 : Icons.login),
                label: Text(
                  _busy
                      ? 'Please wait…'
                      : _createAccount
                          ? 'Create patient account'
                          : 'Sign in to profile',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : _toggleMode,
              child: Text(
                _createAccount
                    ? 'Already have an account? Sign in'
                    : 'New to RapidCare? Create an account',
                style: const TextStyle(
                  color: Color(0xFF00796B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
              child: const Text('Continue as guest'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'Patient').toString();
    final initials = name.trim().split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE0F2F1),
            child: Text(
              initials.isEmpty ? 'P' : initials,
              style: const TextStyle(
                color: Color(0xFF00796B),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Patient account', style: TextStyle(color: Colors.grey)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1),
          ),
          _profileRow('Email', (user['email'] ?? '').toString()),
          const SizedBox(height: 14),
          _profileRow('Phone', '+91 ${(user['phone'] ?? '').toString()}'),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00796B),
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: Color(0xFF80CBC4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF00796B)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
        ),
        isDense: true,
      );

  Widget _profileRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF004D40),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
