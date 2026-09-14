import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'profile_page.dart';

/// Placeholder driver landing screen. Real task assignments and
/// pickup/drop-off navigation arrive with FR-10.
class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Logout', onPressed: () => _logout(context)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No assigned tasks yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                'Task assignments and route navigation will appear here once dispatched.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}