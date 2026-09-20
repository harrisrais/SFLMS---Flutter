import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../firebase_options.dart';

bool firebaseAvailable = false;

Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseAvailable = true;
  } catch (_) {
    firebaseAvailable = false;
  }
}

class AuthService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static bool get isReady => firebaseAvailable;

  static bool isEmailLogin(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  static String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+92')) return '+92${digits.substring(3).replaceFirst(RegExp(r'^0'), '')}';
    if (digits.startsWith('92')) return '+92${digits.substring(2).replaceFirst(RegExp(r'^0'), '')}';
    return '+92${digits.replaceFirst(RegExp(r'^0'), '')}';
  }

  static String _phoneLoginLookupId(String phone, String email) {
    return base64UrlEncode(utf8.encode('${normalizePhone(phone)}|${email.trim().toLowerCase()}'));
  }

  static Future<bool> isPhoneRegisteredForEmail({required String phoneNumber, required String email}) async {
    if (!isReady) throw StateError('Firebase has not been configured. Update firebase_options.dart with your project config.');
    final lookup = await firestore.collection('phoneLoginLookups').doc(_phoneLoginLookupId(phoneNumber, email)).get();
    return lookup.exists;
  }

  static Future<UserCredential> register({
    required String name,
    required String email,
    required String address,
    required String mobile,
    required String password,
    required String role,
  }) async {
    if (!isReady) throw StateError('Firebase has not been configured. Update firebase_options.dart with your project config.');
    final credential = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
    await _saveProfile(credential.user!, name: name, email: email, address: address, mobile: mobile, role: role);
    return credential;
  }

  static Future<void> savePhoneProfile({
    required User user,
    required String name,
    required String email,
    required String address,
    required String mobile,
    required String role,
  }) async {
    if (!isReady) throw StateError('Firebase has not been configured. Update firebase_options.dart with your project config.');
    await _saveProfile(user, name: name, email: email, address: address, mobile: mobile, role: role);
  }

  static Future<void> _saveProfile(
    User user, {
    required String name,
    required String email,
    required String address,
    required String mobile,
    required String role,
  }) async {
    await firestore.collection('users').doc(user.uid).set({
      'userId': const Uuid().v4(),
      'name': name.trim(),
      'email': email.trim(),
      'address': address.trim(),
      'mobileNo': normalizePhone(mobile),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mobile.trim().isNotEmpty) {
      await firestore.collection('phoneLoginLookups').doc(_phoneLoginLookupId(mobile, email)).set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  static Future<void> login({required String email, required String password, required String role}) async {
    if (!isReady) throw StateError('Firebase has not been configured. Update firebase_options.dart with your project config.');
    final loginEmail = email.trim();
    if (!isEmailLogin(loginEmail)) {
      throw FirebaseAuthException(code: 'invalid-email', message: 'Enter a valid email address.');
    }
    await auth.signInWithEmailAndPassword(email: loginEmail, password: password.trim());
    await _ensureRole(role);
  }

  static Future<void> ensurePhoneRole({required String role}) => _ensureRole(role);

  static Future<void> _ensureRole(String role) async {
    final user = auth.currentUser;
    if (user == null) return;
    final profile = await firestore.collection('users').doc(user.uid).get();
    final storedRole = profile.data()?['role'] as String?;
    if (storedRole != null && storedRole != role) {
      await auth.signOut();
      throw FirebaseAuthException(code: 'wrong-role', message: 'This account is registered as a ${storedRole == 'driver' ? 'driver' : 'customer'}.');
    }
  }

  static Future<void> sendPasswordReset({required String email}) async {
    if (!isReady) throw StateError('Firebase has not been configured. Update firebase_options.dart with your project config.');
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<ConfirmationResult?> sendPhoneCode({
  required String phoneNumber,
  String? email,
  required void Function(String verificationId, int? resendToken) onCodeSent,
  required void Function(FirebaseAuthException error) onVerificationFailed,
  required void Function(PhoneAuthCredential credential) onVerificationCompleted,
}) async {
  if (!isReady) {
    throw StateError(
      'Firebase has not been configured. Update firebase_options.dart with your project config.',
    );
  }

  final phone = normalizePhone(phoneNumber);

  debugPrint('PHONE AUTH START');
  debugPrint('Phone: $phone');

  if (email != null && email.trim().isNotEmpty) {
    final registered = await isPhoneRegisteredForEmail(
      phoneNumber: phoneNumber,
      email: email,
    );

    debugPrint('Phone/email registered: $registered');

    if (!registered) {
      throw FirebaseAuthException(
        code: 'phone-not-registered',
        message: 'This email is not registered with that phone number.',
      );
    }
  }

  if (kIsWeb) {
    debugPrint('Starting web phone authentication...');

    try {
      final result = await auth.signInWithPhoneNumber(phone);

      debugPrint('Verification code sent successfully.');

      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('PHONE AUTH ERROR: ${e.code}');
      debugPrint('Message: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PHONE AUTH UNKNOWN ERROR: $e');
      rethrow;
    }
  }

  await auth.verifyPhoneNumber(
    phoneNumber: phone,
    verificationCompleted: onVerificationCompleted,
    verificationFailed: onVerificationFailed,
    codeSent: onCodeSent,
    codeAutoRetrievalTimeout: (verificationId) {
      onCodeSent(verificationId, null);
    },
  );

  return null;
}

  static Future<UserCredential> confirmPhoneCode({
  required String code,
  ConfirmationResult? confirmationResult,
  String? verificationId,
  bool linkToCurrentUser = false,
}) async {
  if (kIsWeb) {
    if (confirmationResult == null) {
      throw FirebaseAuthException(
        code: 'missing-verification',
        message: 'Request a verification code first.',
      );
    }

    debugPrint('CONFIRM PHONE CODE START');
    debugPrint('Code entered: ${code.trim()}');

    try {
      final result = await confirmationResult.confirm(code.trim());

      debugPrint('CONFIRM PHONE CODE SUCCESS');
      debugPrint('UID: ${result.user?.uid}');

      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('CONFIRM PHONE CODE ERROR: ${e.code}');
      debugPrint('Message: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CONFIRM PHONE CODE UNKNOWN ERROR: $e');
      rethrow;
    }
  }

  if (verificationId == null || verificationId.isEmpty) {
    throw FirebaseAuthException(
      code: 'missing-verification',
      message: 'Request a verification code first.',
    );
  }

  final credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: code.trim(),
  );

  if (linkToCurrentUser) {
    return auth.currentUser!.linkWithCredential(credential);
  }

  return auth.signInWithCredential(credential);
}

  static Future<void> verifyPhoneLogin({required String email, required String role}) async {
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'not-authenticated', message: 'Phone verification did not complete.');
    final profile = await firestore.collection('users').doc(user.uid).get();
    final data = profile.data();
    final registeredEmail = (data?['email'] as String? ?? '').trim().toLowerCase();
    if (!profile.exists) {
      try {
        await user.delete();
      } catch (_) {
        await auth.signOut();
      }
      throw FirebaseAuthException(code: 'phone-not-registered', message: 'You have not registered this phone number.');
    }
    if (registeredEmail != email.trim().toLowerCase()) {
      await auth.signOut();
      throw FirebaseAuthException(code: 'phone-not-registered', message: 'You have not registered this phone number with that email address.');
    }
    await _ensureRole(role);
  }

  static Future<ConfirmationResult?> sendPhoneLinkCode({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'not-authenticated', message: 'Log in before registering a phone number.');
    if (kIsWeb) return user.linkWithPhoneNumber(normalizePhone(phoneNumber));
    await auth.verifyPhoneNumber(
      phoneNumber: normalizePhone(phoneNumber),
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (verificationId) => onCodeSent(verificationId, null),
    );
    return null;
  }

  static Future<Map<String, dynamic>> fetchProfile() async {
    if (!isReady) throw StateError('Firebase has not been configured. Update firebase_options.dart with your project config.');
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'not-authenticated', message: 'User is not logged in.');
    final doc = await firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw FirebaseException(plugin: 'cloud_firestore', code: 'user-not-found', message: 'User profile not found in Firestore.');
    return doc.data() ?? {};
  }

  static Future<void> updateProfile({
  required String name,
  required String email,
  required String address,
  required String mobile,
}) async {
  if (!isReady) {
    throw StateError(
      'Firebase has not been configured. Update firebase_options.dart with your project config.',
    );
  }

  final user = auth.currentUser;

  if (user == null) {
    throw FirebaseAuthException(
      code: 'not-authenticated',
      message: 'User is not logged in.',
    );
  }

  final profileEmail = email.trim();
  final authEmail = user.email?.trim();

  // Email/password users have a Firebase Auth email.
  // Do not allow changing it in this prototype.
  //
  // Phone users have no Firebase Auth email, so their
  // Firestore profile email can be updated normally.
  if (authEmail != null &&
      authEmail.isNotEmpty &&
      profileEmail.toLowerCase() != authEmail.toLowerCase()) {
    throw FirebaseAuthException(
      code: 'email-change-forbidden',
      message:
          'Email is managed by Firebase Auth and cannot be changed in this prototype.',
    );
  }

  await firestore.collection('users').doc(user.uid).update({
    'name': name.trim(),
    'email': profileEmail,
    'address': address.trim(),
    'mobileNo': normalizePhone(mobile),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  if (mobile.trim().isNotEmpty) {
    await firestore
        .collection('phoneLoginLookups')
        .doc(_phoneLoginLookupId(mobile, profileEmail))
        .set({
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

  static Future<void> signOut() async {
    if (isReady) await auth.signOut();
  }
}
