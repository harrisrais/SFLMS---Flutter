import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _phoneCodeRequested = false;
  bool _phoneSaving = false;
  String? _phoneVerificationId;
  ConfirmationResult? _phoneConfirmationResult;
  List<TextEditingController>? _phoneCodeControllers;

  List<TextEditingController> get _phoneCodeFields => _phoneCodeControllers ??= List.generate(6, (_) => TextEditingController());
  String get _phoneCode => _phoneCodeFields.map((controller) => controller.text).join();

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.fetchProfile();
      if (!mounted) return;
      _nameController.text = profile['name'] ?? '';
      _emailController.text = profile['email'] ?? '';
      _addressController.text = profile['address'] ?? '';
      final savedPhone = profile['mobileNo'] as String? ?? '';
      final normalizedPhone = savedPhone.isEmpty ? '' : AuthService.normalizePhone(savedPhone);
      _mobileController.text = normalizedPhone.startsWith('+92') ? normalizedPhone.substring(3) : normalizedPhone;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load profile: $e')));
    }
  }

  Future<void> _registerPhone() async {
    if (_mobileController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit Pakistan phone number.')));
      return;
    }
    setState(() => _phoneSaving = true);
    try {
      if (!_phoneCodeRequested) {
        _phoneConfirmationResult = await AuthService.sendPhoneLinkCode(
          phoneNumber: _mobileController.text,
          onCodeSent: (id, _) => setState(() { _phoneVerificationId = id; _phoneCodeRequested = true; }),
          onVerificationFailed: (error) => _showMessage(error.message ?? 'Could not send verification code.'),
          onVerificationCompleted: (credential) => _completePhoneLink(credential),
        );
        if (_phoneConfirmationResult != null && mounted) setState(() => _phoneCodeRequested = true);
        if (mounted) _showMessage('Verification code sent.');
      } else {
        await AuthService.confirmPhoneCode(code: _phoneCode, confirmationResult: _phoneConfirmationResult, verificationId: _phoneVerificationId, linkToCurrentUser: true);
        await _savePhoneProfile();
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Phone registration failed.');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _phoneSaving = false);
    }
  }

  Future<void> _completePhoneLink(PhoneAuthCredential credential) async {
    try {
      await AuthService.auth.currentUser!.linkWithCredential(credential);
      await _savePhoneProfile();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Phone registration failed.');
    }
  }

  Future<void> _savePhoneProfile() async {
    await AuthService.updateProfile(name: _nameController.text, email: _emailController.text, address: _addressController.text, mobile: _mobileController.text);
    if (!mounted) return;
    setState(() => _phoneCodeRequested = false);
    _showMessage('Phone number registered successfully.');
  }

  Widget _phoneCodeInput() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, (index) => SizedBox(width: 44, child: TextFormField(controller: _phoneCodeFields[index], textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 1, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()), onChanged: (value) { if (value.isNotEmpty && index < 5) FocusScope.of(context).nextFocus(); }))));

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.updateProfile(name: _nameController.text, email: _emailController.text, address: _addressController.text, mobile: _mobileController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon));
  String? _required(String? value, String message) => value == null || value.trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), centerTitle: true, actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded), tooltip: 'Logout')]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(color: const Color(0xFF0F172A), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Container(width: 68, height: 68, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.local_shipping, size: 34, color: Colors.white)), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SFLMS User Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 6), const Text('Update your account and logistics details.', style: TextStyle(color: Colors.white70, fontSize: 14))]))]))),
        const SizedBox(height: 22),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          TextFormField(controller: _nameController, decoration: _decoration('Full Name', Icons.person_outline), validator: (v) => _required(v, 'Enter your name')),
          const SizedBox(height: 16), TextFormField(controller: _emailController, readOnly: true, decoration: _decoration('Email', Icons.email_outlined), validator: (v) => _required(v, 'Enter email')),
          const SizedBox(height: 16), TextFormField(controller: _addressController, maxLines: 2, decoration: _decoration('Address', Icons.location_on_outlined), validator: (v) => _required(v, 'Enter address')),
          const SizedBox(height: 16), TextFormField(controller: _mobileController, keyboardType: TextInputType.phone, maxLength: 10, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _decoration('Pakistan Phone Number', Icons.phone_android_outlined).copyWith(prefixText: '+92 '), validator: (v) => _required(v, 'Enter mobile number')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _phoneSaving ? null : _registerPhone, icon: const Icon(Icons.verified_user_outlined), label: Text(_phoneCodeRequested ? 'Verify phone number' : 'Register phone number')),
          if (_phoneCodeRequested) ...[const SizedBox(height: 12), const Text('Enter the 6-digit verification code'), const SizedBox(height: 8), _phoneCodeInput()],
          const SizedBox(height: 24), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _saveProfile, icon: const Icon(Icons.save_alt_rounded), label: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save changes', maxLines: 1, overflow: TextOverflow.ellipsis), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), backgroundColor: const Color(0xFF0F766E)))),
        ]))),
      ]))))),
    );
  }
}
