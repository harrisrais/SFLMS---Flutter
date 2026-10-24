import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/vehicle_category.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/notification_service.dart';
import '../login_page.dart';
import '../profile_page.dart';
import 'my_requests_page.dart';
import 'notifications_page.dart';
import 'search_page.dart';


/// Shows available vehicle categories from Firestore and provides access to
/// fleet search.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  bool _seeding = false;

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  Future<void> _seedSampleData() async {
    setState(() => _seeding = true);
    try {
      await CatalogService.seedSampleCatalog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load sample fleet data: $e')));
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _openSearch({VehicleCategory? category}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchPage(initialCategory: category)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: const Text('Customer Dashboard'),
                actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: NotificationService.streamForUser(AuthService.auth.currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              final unread = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .where((doc) => doc.data()['read'] != true)
                  .length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(
                          '$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'My Requests',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyRequestsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Logout', onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Where are you shipping today?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Pick a vehicle category or search the full fleet.', style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _openSearch(),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search fleet by location & load'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                sliver: StreamBuilder<List<VehicleCategory>>(
                  stream: CatalogService.streamActiveCategories(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),
                      );
                    }
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text('Could not load vehicle categories: ${snapshot.error}'),
                        ),
                      );
                    }
                    final categories = snapshot.data ?? const [];
                    if (categories.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 40, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text('No vehicle categories yet', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                  'Load sample fleet data to try the dashboard and search.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _seeding ? null : _seedSampleData,
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: Text(_seeding ? 'Loading…' : 'Load sample fleet data'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.95,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category = categories[index];
                          return _CategoryCard(category: category, onTap: () => _openSearch(category: category));
                        },
                        childCount: categories.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});
  final VehicleCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFECFEFF), borderRadius: BorderRadius.circular(14)),
                child: Icon(category.icon, color: const Color(0xFF0F766E), size: 28),
              ),
              const Spacer(),
              Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(category.capacityRangeLabel, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
