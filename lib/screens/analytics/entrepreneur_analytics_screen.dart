import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart' as m;
import '../../services/firestore_service.dart';

class EntrepreneurAnalyticsScreen extends StatelessWidget {
  EntrepreneurAnalyticsScreen({super.key});

  final _fs = FirestoreService();

  String get _entrepreneurId =>
      FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitik Jualan'),
      ),
      body: StreamBuilder<List<m.Order>>(
        stream: _fs.ordersForEntrepreneur(_entrepreneurId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ralat memuatkan analitik: ${snapshot.error}',
              ),
            );
          }

          final orders = snapshot.data ?? <m.Order>[];
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada pesanan. Analitik akan muncul di sini.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final totalRevenue =
              orders.fold<double>(0, (sum, o) => sum + o.total);
          final totalOrders = orders.length;

          // Kira jualan per produk
          final productRevenue = <String, double>{};
          for (final o in orders) {
            for (final line in o.lines) {
              productRevenue.update(
                line.productName,
                (value) => value + line.lineTotal,
                ifAbsent: () => line.lineTotal,
              );
            }
          }

          final topProducts = productRevenue.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topFive = topProducts.take(5).toList();
          final maxRevenue =
              topFive.isNotEmpty ? topFive.first.value : 1.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _MetricCard(
                    title: 'Jumlah jualan',
                    value: 'RM ${totalRevenue.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    title: 'Bilangan pesanan',
                    value: '$totalOrders',
                    icon: Icons.receipt_long,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Top 5 produk mengikut jualan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // ---------- BAR CHART (FIXED OVERFLOW) ----------
              if (topFive.isEmpty)
                const Text('Belum ada data produk.')
              else
                SizedBox(
                  height: 220,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Simpan ruang untuk teks di atas & bawah bar
                      final maxBarHeight =
                          (constraints.maxHeight - 60).clamp(0.0, 1000.0);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: topFive.map((entry) {
                          final ratio = entry.value / maxRevenue;
                          final barHeight = maxBarHeight * ratio;

                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'RM ${entry.value.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2E7D32),
                                        Color(0xFFFFD54F),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.key,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              // ---------- END BAR CHART ----------

              const SizedBox(height: 24),
              const Text(
                'Pesanan terkini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...orders.take(5).map((o) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt),
                    title: Text('Pesanan #${o.code}'),
                    subtitle: Text(
                      '${o.lines.length} item • ${o.createdAtFormatted}',
                    ),
                    trailing: Text(
                      'RM ${o.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
