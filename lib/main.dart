import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/role_router.dart';
import 'services/auth_service.dart';

export 'pages/login_page.dart';
export 'pages/profile_page.dart';
export 'pages/register_page.dart';
export 'pages/role_router.dart';
export 'pages/customer/home_page.dart';
export 'pages/customer/search_page.dart';
export 'pages/customer/booking_page.dart';
export 'pages/customer/my_requests_page.dart';
export 'pages/customer/notifications_page.dart';
export 'pages/driver_home_page.dart';
export 'pages/admin/admin_home_page.dart';
export 'services/auth_service.dart';
export 'services/catalog_service.dart';
export 'services/distance_service.dart';
export 'services/pricing_service.dart';
export 'services/notification_service.dart';
export 'models/vehicle_category.dart';
export 'models/fleet_vehicle.dart';
export 'models/shipment_request.dart';
export 'models/app_notification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const SflmsApp());
}

class SflmsApp extends StatelessWidget {
  const SflmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SFLMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E), brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!firebaseAvailable) return const LoginPage();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData && snapshot.data != null ? const RoleRouter() : const LoginPage();
      },
    );
  }
}
