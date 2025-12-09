import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../analytics/entrepreneur_analytics_screen.dart';
import '../announcements/announcements_screen.dart';
import '../cart/cart_screen.dart';
import '../products/customer_products_screen.dart';
import '../products/products_screen.dart';
import '../profile/customer_profile_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _authService = AuthService();
  final _cart = CartService.instance;

  int _index = 0;
  UserRole? _role;
  bool _loadingRole = true;

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

    final isEntrepreneur = _role == UserRole.entrepreneur;

    final entrepreneurScreens = <Widget>[
      const ProductsScreen(),
      const AnnouncementsScreen(),
      EntrepreneurAnalyticsScreen(),
      const ProfileScreen(),
    ];

    final customerScreens = <Widget>[
      const CustomerProductsScreen(),
      const AnnouncementsScreen(),
      CartScreen(cartService: _cart),
      const CustomerProfileScreen(),
    ];

    final screens =
        isEntrepreneur ? entrepreneurScreens : customerScreens;

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

          // Items for usahawan
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

          // Items for customer – show badge with cartCount
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
                          color:
                              Theme.of(context).colorScheme.error,
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
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
          ];

          return BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            items: isEntrepreneur
                ? entrepreneurItems
                : customerItems,
          );
        },
      ),
    );
  }
}
