import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart' as m;
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/firestore_service.dart';
import '../analytics/entrepreneur_analytics_screen.dart';
import '../announcements/announcements_screen.dart';
import '../cart/cart_screen.dart';
import '../products/customer_products_screen.dart';
import '../products/products_screen.dart';
import '../profile/customer_profile_screen.dart';
import '../profile/profile_screen.dart';
import '../entrepreneurs/customer_entrepreneur_search_screen.dart'; // NEW

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _authService = AuthService();
  final _cart = CartService.instance;
  final _fs = FirestoreService();

  int _index = 0;
  UserRole? _role;
  bool _loadingRole = true;

  bool _welcomeShown = false; // ensure popup only once

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loadingRole = false;
        _role = null;
      });
      return;
    }

    final role = await _authService.getUserRole(user.uid);
    setState(() {
      _role = role;
      _loadingRole = false;
      _index = 0;
    });
  }

  Future<void> _showWelcomeIfNeeded() async {
    if (_welcomeShown || !mounted) return;
    if (_role != UserRole.entrepreneur) return; // ONLY entrepreneur
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _welcomeShown = true; // mark as used

    // Orders for this entrepreneur
    List<m.Order> orders;
    try {
      orders = await _fs.ordersForEntrepreneur(user.uid).first;
    } catch (_) {
      orders = [];
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final todaysOrders = orders.where((o) {
      return o.createdAt.isAfter(startOfDay);
    }).toList();

    final todayCount = todaysOrders.length;
    final todayTotal = todaysOrders.fold<double>(
      0,
      (sum, o) => sum + o.total,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);

        const title = 'Ringkasan hari ini';
        const subtitle = 'Prestasi jualan terkini untuk kedai anda.';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _WelcomeStatChip(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Pesanan hari ini',
                      value: todayCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WelcomeStatChip(
                      icon: Icons.payments_outlined,
                      label: 'Nilai hari ini',
                      value: 'RM ${todayTotal.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Teruskan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_role == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Peranan pengguna tidak ditemui. Sila hubungi pentadbir.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Once role is loaded, schedule welcome popup (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeIfNeeded();
    });

    final isEntrepreneur = _role == UserRole.entrepreneur;

    // TAB SUSUNAN USAHAWAN
    final entrepreneurScreens = <Widget>[
      const ProductsScreen(),
      const AnnouncementsScreen(),
      EntrepreneurAnalyticsScreen(),
      const ProfileScreen(),
    ];

    // TAB SUSUNAN PELANGGAN – TAMBAH TAB USAHAWAN DI SEBELAH TROLI
    final customerScreens = <Widget>[
      const CustomerProductsScreen(), // index 0
      const AnnouncementsScreen(), // index 1
      CartScreen(cartService: _cart), // index 2 (Troli)
      const CustomerEntrepreneurSearchScreen(), // index 3 (Usahawan)
      const CustomerProfileScreen(), // index 4 (Profil)
    ];

    final screens = isEntrepreneur ? entrepreneurScreens : customerScreens;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _cart,
        builder: (context, _) {
          final cartCount =
              _cart.items.fold<int>(0, (sum, item) => sum + item.quantity);

          // Items untuk usahawan (tidak berubah)
          const entrepreneurItems = <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Produk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              label: 'Hebahan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              label: 'Analitik',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
          ];

          // Items untuk pelanggan – dengan badge di Troli dan tab Usahawan
          final customerItems = <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              label: 'Produk',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              label: 'Hebahan',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (cartCount > 0)
                    Positioned(
                      right: -6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          cartCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Troli',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              label: 'Usahawan',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
          ];

          return BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            items: isEntrepreneur ? entrepreneurItems : customerItems,
          );
        },
      ),
    );
  }
}

class _WelcomeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WelcomeStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
