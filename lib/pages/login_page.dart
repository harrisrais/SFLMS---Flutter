import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'register_page.dart';
import 'role_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<TextEditingController>? _codeControllers;

  String _role = 'customer';
  bool _phoneMode = false;
  bool _codeRequested = false;
  bool _isSubmitting = false;

  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  List<TextEditingController> get _codeFields =>
      _codeControllers ??=
          List.generate(6, (_) => TextEditingController());

  String get _verificationCode =>
      _codeFields.map((controller) => controller.text).join();

  Widget _codeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        6,
        (index) => SizedBox(
          width: 44,
          child: TextFormField(
            controller: _codeFields[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                FocusScope.of(context).nextFocus();
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_phoneMode) {
        await _loginWithPhone();
      } else {
        await _loginWithEmail();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message ?? 'Authentication failed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _loginWithPhone() async {
    if (!_codeRequested) {
      _confirmationResult = await AuthService.sendPhoneCode(
        phoneNumber: _identifierController.text.trim(),
        email: _emailController.text.trim(),
        onCodeSent: (id, _) {
          if (!mounted) return;

          setState(() {
            _verificationId = id;
            _codeRequested = true;
          });
        },
        onVerificationFailed: (error) {
          if (!mounted) return;

          _showMessage(
            error.message ?? 'Could not send verification code.',
          );
        },
        onVerificationCompleted: (credential) {
          unawaited(
            _completePhoneCredential(credential),
          );
        },
      );

      if (kIsWeb && mounted) {
        setState(() => _codeRequested = true);
      }

      if (mounted) {
        _showMessage('Verification code sent.');
      }

      return;
    }

    if (_verificationCode.length != 6) {
      _showMessage('Enter the complete 6-digit verification code.');
      return;
    }

    await AuthService.confirmPhoneCode(
      code: _verificationCode,
      confirmationResult: _confirmationResult,
      verificationId: _verificationId,
    );

    await AuthService.verifyPhoneLogin(
      email: _emailController.text.trim(),
      role: _role,
    );

    await _openProfile();
  }

  Future<void> _loginWithEmail() async {
    await AuthService.login(
      email: _identifierController.text.trim(),
      password: _passwordController.text,
      role: _role,
    );

    await _openProfile();
  }

  Future<void> _completePhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      await AuthService.auth.signInWithCredential(credential);

      await AuthService.verifyPhoneLogin(
        email: _emailController.text.trim(),
        role: _role,
      );

      await _openProfile();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? 'Phone verification failed.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString());
    }
  }

  Future<void> _openProfile() async {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RoleRouter(),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _identifierController.text.trim();

    if (!AuthService.isEmailLogin(email)) {
      _showMessage(
        'Enter your email first to reset your password.',
      );
      return;
    }

    try {
      await AuthService.sendPasswordReset(
        email: email,
      );

      if (!mounted) return;

      _showMessage(
        'Password reset email sent.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? 'Could not send password reset email.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    for (final controller in _codeFields) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF0F766E),
              Color(0xFF14B8A6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: Card(
                  color: Colors.white.withValues(alpha: 0.96),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFEFF),
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.local_shipping,
                              size: 46,
                              color: Color(0xFF0F766E),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Smart Fleet & Logistics',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Sign in to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                            ),
                          ),

                          const SizedBox(height: 22),

                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: 'customer',
                                label: Text('Customer'),
                                icon: Icon(
                                  Icons.person_outline,
                                ),
                              ),
                              ButtonSegment(
                                value: 'driver',
                                label: Text('Driver'),
                                icon: Icon(
                                  Icons.local_shipping_outlined,
                                ),
                              ),
                              ButtonSegment(
                                value: 'admin',
                                label: Text('Admin'),
                                icon: Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                              ),
                            ],
                            selected: {_role},
                            onSelectionChanged: _isSubmitting
                                ? null
                                : (value) {
                                    setState(() {
                                      _role = value.first;
                                    });
                                  },
                          ),

                          const SizedBox(height: 16),

                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Email'),
                                icon: Icon(
                                  Icons.email_outlined,
                                ),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Phone'),
                                icon: Icon(
                                  Icons.phone_outlined,
                                ),
                              ),
                            ],
                            selected: {_phoneMode},
                            onSelectionChanged: _isSubmitting
                                ? null
                                : (value) {
                                    setState(() {
                                      _phoneMode = value.first;
                                      _codeRequested = false;

                                      for (final controller
                                          in _codeFields) {
                                        controller.clear();
                                      }
                                    });
                                  },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _identifierController,
                            keyboardType: _phoneMode
                                ? TextInputType.phone
                                : TextInputType.emailAddress,
                            maxLength:
                                _phoneMode ? 10 : null,
                            inputFormatters: _phoneMode
                                ? [
                                    FilteringTextInputFormatter
                                        .digitsOnly,
                                  ]
                                : null,
                            decoration: InputDecoration(
                              labelText: _phoneMode
                                  ? 'Pakistan phone number'
                                  : 'Email',
                              prefixText:
                                  _phoneMode ? '+92 ' : null,
                              border:
                                  const OutlineInputBorder(),
                              prefixIcon: Icon(
                                _phoneMode
                                    ? Icons.phone_outlined
                                    : Icons.email_outlined,
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return _phoneMode
                                    ? 'Enter your phone number'
                                    : 'Enter your email';
                              }

                              if (_phoneMode &&
                                  value.trim().length != 10) {
                                return 'Enter a valid 10-digit phone number';
                              }

                              if (!_phoneMode &&
                                  !AuthService.isEmailLogin(
                                    value,
                                  )) {
                                return 'Enter a valid email';
                              }

                              return null;
                            },
                          ),

                          if (_phoneMode) ...[
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _emailController,
                              keyboardType:
                                  TextInputType.emailAddress,
                              decoration:
                                  const InputDecoration(
                                labelText: 'Registration email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    !AuthService.isEmailLogin(
                                      value,
                                    )) {
                                  return 'Enter the registration email';
                                }

                                return null;
                              },
                            ),
                          ],

                          if (!_phoneMode) ...[
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration:
                                  const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Enter password';
                                }

                                return null;
                              },
                            ),

                            Align(
                              alignment:
                                  Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _resetPassword,
                                child: const Text(
                                  'Forgot password?',
                                ),
                              ),
                            ),
                          ],

                          if (_phoneMode &&
                              _codeRequested) ...[
                            const SizedBox(height: 16),

                            const Text(
                              'Enter the 6-digit verification code',
                            ),

                            const SizedBox(height: 8),

                            _codeInput(),
                          ],

                          const SizedBox(height: 12),

                          FilledButton.icon(
                            onPressed:
                                _isSubmitting ? null : _submit,
                            icon: const Icon(
                              Icons.login_rounded,
                            ),
                            label: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _phoneMode &&
                                            !_codeRequested
                                        ? 'Send code'
                                        : 'Login',
                                  ),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              backgroundColor:
                                  const Color(0xFF0F766E),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment:
                                WrapCrossAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account?",
                              ),
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        Navigator.of(context)
                                            .push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                RegisterPage(
                                              initialRole:
                                                  _role,
                                            ),
                                          ),
                                        );
                                      },
                                child:
                                    const Text('Register'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}