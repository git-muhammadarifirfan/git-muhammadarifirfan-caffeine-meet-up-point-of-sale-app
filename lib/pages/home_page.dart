import 'package:flutter/material.dart';
import 'package:pos_coffeeshop_ayudian/pages/category_page.dart';
import '../core/session.dart';
import '../core/pos_ui.dart';
import 'kasir_page.dart';
import 'product_page.dart';
import 'transaction_page.dart';
import 'stats_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = Session.role == 'admin';

    final pages = isAdmin
        ? const [
            KasirPage(),
            ProductPage(), // ADMIN ONLY
            CategoryPage(),
            TransactionPage(),
            StatsPage(),
            ProfilePage(),
          ]
        : const [
            KasirPage(),
            TransactionPage(),
            ProfilePage(),
          ];

    final destinations = isAdmin
    ? const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: 'Kasir',
        ),
        NavigationDestination(
          icon: Icon(Icons.widgets_outlined),
          selectedIcon: Icon(Icons.widgets),
          label: 'Produk',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'Kategori',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_outlined),
          selectedIcon: Icon(Icons.receipt),
          label: 'Transaksi',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights),
          label: 'Report',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: 'Profil',
        ),
      ]
    : const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          label: 'Kasir',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_outlined),
          selectedIcon: Icon(Icons.receipt),
          label: 'Transaksi',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: 'Profil',
        ),
      ];

    return PosBackground(
      child: Scaffold(
        extendBody: true,
        body: pages[index],
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: PosTokens.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(0, 0, 0, 0),
                    blurRadius: 24,
                    offset: Offset(0, 0),
                  )
                ],
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                destinations: destinations,
              ),
            ),
          ),
        ),
      ),
    );
  }
}