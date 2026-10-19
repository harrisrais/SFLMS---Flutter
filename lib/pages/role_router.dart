import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'admin/home_page.dart';
import 'customer/home_page.dart';
import 'driver/home_page.dart';
import 'profile_page.dart';

/// After authentication, routes the user to their role-specific home screen
/// based on the `role` field saved on their Firestore profile.
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final Future<String?> _roleFuture = _loadRole();

  Future<String?> _loadRole() async {
    try {
      final profile = await AuthService.fetchProfile();
      await NotificationService.registerDevice();
      return profile['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        switch (snapshot.data) {
          case 'admin':
            return const AdminHomePage();
          case 'driver':
            return const DriverHomePage();
          case 'customer':
            return const CustomerHomePage();
          default:
            return const ProfilePage();
        }
      },
    );
  }
}