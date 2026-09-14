import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'role_router.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialRole = 'customer'});
  final String initialRole;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  List<TextEditingController>? _codeControllers;
  late String _role = widget.initialRole;
  bool _phoneMode = false;
  bool _codeRequested = false;
  bool _isSubmitting = false;
  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  List<TextEditingController> get _codeFields => _codeControllers ??= List.generate(6, (_) => TextEditingController());
  String get _verificationCode => _codeFields.map((controller) => controller.text).join();

  Widget _codeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) => SizedBox(
        width: 44,
        child: TextFormField(
          controller: _codeFields[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
          onChanged: (value) { if (value.isNotEmpty && index < 5) FocusScope.of(context).nextFocus(); },
          validator: (value) => value == null || value.isEmpty ? '' : null,
        ),
      )),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      if (_phoneMode) {
        if (!_codeRequested) {
          _confirmationResult = await AuthService.sendPhoneCode(
            phoneNumber: _mobileController.text,
            onCodeSent: (id, _) => setState(() { _verificationId = id; _codeRequested = true; }),
            onVerificationFailed: (error) => _showMessage(error.message ?? 'Could not send verification code.'),
            onVerificationCompleted: (credential) => unawaited(_completePhoneRegistration(credential)),
          );
          if (kIsWeb && mounted) setState(() => _codeRequested = true);
          if (mounted) _showMessage('Verification code sent.');
        } else {
          final credential = await AuthService.confirmPhoneCode(code: _verificationCode, confirmationResult: _confirmationResult, verificationId: _verificationId);
          await AuthService.savePhoneProfile(user: credential.user!, name: _nameController.text, email: _emailController.text, address: _addressController.text, mobile: _mobileController.text, role: _role);
          await _openProfile();
        }
      } else {
        await AuthService.register(name: _nameController.text, email: _emailController.text, address: _addressController.text, mobile: _mobileController.text, password: _passwordController.text, role: _role);
        if (!mounted) return;
        _showMessage('Registration successful. You can now log in.');
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Registration failed.');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completePhoneRegistration(PhoneAuthCredential credential) async {
    try {
      final result = await AuthService.auth.signInWithCredential(credential);
      await AuthService.savePhoneProfile(user: result.user!, name: _nameController.text, email: _emailController.text, address: _addressController.text, mobile: _mobileController.text, role: _role);
      await _openProfile();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Phone verification failed.');
    }
  }

  Future<void> _openProfile() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RoleRouter()));
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon));
  String? _required(String? value, String message) => value == null || value.trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 8),
                  const Text('Register your profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Create an account as a customer or driver.', style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(segments: const [ButtonSegment(value: 'customer', label: Text('Customer'), icon: Icon(Icons.person_outline)), ButtonSegment(value: 'driver', label: Text('Driver'), icon: Icon(Icons.local_shipping_outlined))], selected: {_role}, onSelectionChanged: (value) => setState(() => _role = value.first)),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Email and password'), icon: Icon(Icons.email_outlined)), ButtonSegment(value: true, label: Text('Phone verification'), icon: Icon(Icons.phone_outlined))], selected: {_phoneMode}, onSelectionChanged: (value) => setState(() { _phoneMode = value.first; _codeRequested = false; })),
                  const SizedBox(height: 16),
                  Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                    TextFormField(controller: _nameController, decoration: _decoration('Full Name', Icons.person_outline), validator: (v) => _required(v, 'Enter full name')),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _decoration('Registration Email', Icons.email_outlined), validator: (v) { if (_required(v, 'Enter email') != null) return 'Enter email'; if (!AuthService.isEmailLogin(v!)) return 'Enter valid email'; return null; }),
                    const SizedBox(height: 16),
                    TextFormField(controller: _addressController, maxLines: 2, decoration: _decoration('Address', Icons.home_outlined), validator: (v) => _required(v, 'Enter address')),
                    if (_phoneMode) ...[
                      const SizedBox(height: 16),
                      TextFormField(controller: _mobileController, keyboardType: TextInputType.phone, maxLength: 10, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _decoration('Pakistan Phone Number', Icons.phone_android_outlined).copyWith(prefixText: '+92 '), validator: (v) => _required(v, 'Enter phone number')),
                    ],
                    if (!_phoneMode) ...[
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordController, obscureText: true, decoration: _decoration('Password', Icons.lock_outline), validator: (v) => v == null || v.trim().length < 6 ? 'Password must be 6+ characters' : null),
                    ],
                    if (_phoneMode && _codeRequested) ...[const SizedBox(height: 16), const Text('Enter the 6-digit verification code'), const SizedBox(height: 8), _codeInput()],
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _isSubmitting ? null : _register, icon: const Icon(Icons.app_registration_rounded), label: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_phoneMode && !_codeRequested ? 'Send verification code' : 'Register now'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF0F766E)))),
                  ]))),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())), child: const Text('Already have an account? Login')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
