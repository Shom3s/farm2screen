import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/order.dart' as m;
import '../../models/customer.dart';
import '../../services/firestore_service.dart';

class EntrepreneurAnalyticsScreen extends StatefulWidget {
  const EntrepreneurAnalyticsScreen({super.key});

  @override
  State<EntrepreneurAnalyticsScreen> createState() =>
      _EntrepreneurAnalyticsScreenState();
}

class _EntrepreneurAnalyticsScreenState
    extends State<EntrepreneurAnalyticsScreen> {
  final _fs = FirestoreService();

  String get _entrepreneurId => FirebaseAuth.instance.currentUser!.uid;

  // 0 = Hari ini, 1 = Bulan ini, 2 = Semua
  int _rangeIndex = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ralat memuatkan analitik:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allOrders = snapshot.data ?? <m.Order>[];
          if (allOrders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada pesanan.\nAnalitik akan muncul di sini sebaik sahaja anda menerima pesanan.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // ============ FILTER IKUT JULAT MASA ============
          final filteredOrders =
              _filterOrdersByRange(allOrders, _rangeIndex);

          // ----------------- BASIC METRICS -----------------
          final totalRevenue =
              filteredOrders.fold<double>(0, (sum, o) => sum + o.total);
          final totalOrders = filteredOrders.length;
          final averageOrder =
              totalOrders == 0 ? 0.0 : totalRevenue / totalOrders;

          // Jualan per produk (ikut julat masa dipilih)
          final productRevenue = <String, double>{};
          for (final o in filteredOrders) {
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

          return Container(
            color: theme.colorScheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----------------- HERO CARD -----------------
                  _TotalRevenueCard(
                    totalRevenue: totalRevenue,
                    totalOrders: totalOrders,
                    rangeIndex: _rangeIndex,
                    onRangeChanged: (i) {
                      setState(() {
                        _rangeIndex = i;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // ----------------- SMALL METRIC CARDS -----------------
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Purata nilai\npesanan',
                          value:
                              'RM ${averageOrder.toStringAsFixed(2)}',
                          subtitle: 'Setiap pesanan',
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'Jumlah\npesanan',
                          value: '$totalOrders',
                          subtitle: _rangeSubtitle(_rangeIndex),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ----------------- TOP PRODUCTS CARD -----------------
                  _TopProductsCard(
                    topFive: topFive,
                    maxRevenue: maxRevenue,
                  ),

                  const SizedBox(height: 20),

                  // ----------------- RECENT ORDERS CARD -----------------
                  _RecentOrdersCard(
                    orders: filteredOrders,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Tapis senarai order mengikut julat masa dipilih.
  List<m.Order> _filterOrdersByRange(
      List<m.Order> orders, int rangeIndex) {
    final now = DateTime.now();

    if (rangeIndex == 0) {
      // Hari ini
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      return orders.where((o) {
        final t = o.createdAt;
        return t.isAfter(today) && t.isBefore(tomorrow);
      }).toList();
    } else if (rangeIndex == 1) {
      // Bulan ini
      final firstDay = DateTime(now.year, now.month, 1);
      final nextMonth = (now.month == 12)
          ? DateTime(now.year + 1, 1, 1)
          : DateTime(now.year, now.month + 1, 1);
      return orders.where((o) {
        final t = o.createdAt;
        return t.isAfter(firstDay) && t.isBefore(nextMonth);
      }).toList();
    } else {
      // Semua
      return orders;
    }
  }

  String _rangeSubtitle(int index) {
    switch (index) {
      case 0:
        return 'Hari ini';
      case 1:
        return 'Bulan ini';
      default:
        return 'Semua tempoh';
    }
  }
}

/// Hero-style card di bahagian atas (jumlah jualan + range pills)
class _TotalRevenueCard extends StatelessWidget {
  final double totalRevenue;
  final int totalOrders;
  final int rangeIndex;
  final ValueChanged<int> onRangeChanged;

  const _TotalRevenueCard({
    required this.totalRevenue,
    required this.totalOrders,
    required this.rangeIndex,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = 'RM ${totalRevenue.toStringAsFixed(2)}';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + icon
            Row(
              children: [
                Text(
                  'Jumlah jualan',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.show_chart_rounded,
                  color: theme.colorScheme.onPrimary.withOpacity(0.9),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amountText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalOrders pesanan diterima',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.85),
              ),
            ),

            const SizedBox(height: 18),

            // Fake sparkline area
            SizedBox(
              height: 70,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color:
                            theme.colorScheme.onPrimary.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: 12,
                    right: 12,
                    top: 8,
                    bottom: 12,
                    child: CustomPaint(
                      painter: _SimpleSparklinePainter(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Range selector chips
            Row(
              children: [
                _RangeChip(
                  label: 'Hari ini',
                  index: 0,
                  selectedIndex: rangeIndex,
                  onTap: onRangeChanged,
                ),
                const SizedBox(width: 8),
                _RangeChip(
                  label: 'Bulan ini',
                  index: 1,
                  selectedIndex: rangeIndex,
                  onTap: onRangeChanged,
                ),
                const SizedBox(width: 8),
                _RangeChip(
                  label: 'Semua',
                  index: 2,
                  selectedIndex: rangeIndex,
                  onTap: onRangeChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _RangeChip({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = index == selectedIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Kad kecil untuk metrik ringkas di bawah hero card
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  theme.colorScheme.primary.withOpacity(0.12),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kad dengan bar chart "Top 5 produk"
class _TopProductsCard extends StatelessWidget {
  final List<MapEntry<String, double>> topFive;
  final double maxRevenue;

  const _TopProductsCard({
    required this.topFive,
    required this.maxRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Top produk',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Top 5',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mengikut jumlah jualan',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            if (topFive.isEmpty)
              const Text('Belum ada data produk untuk julat masa ini.')
            else
              SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, constraints) {
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
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.secondary,
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
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kad "Pesanan terkini" (ikut julat masa dipilih)
class _RecentOrdersCard extends StatelessWidget {
  final List<m.Order> orders;

  const _RecentOrdersCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = orders.toList()..sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );
    final display = latest.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Pesanan terkini',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Mengikut julat dipilih',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (display.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Tiada pesanan dalam julat masa ini.'),
              )
            else
              ...display.map((o) {
                return ListTile(
                  dense: false,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.08),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    'Pesanan #${o.code}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${o.lines.length} item • ${o.createdAtFormatted}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  trailing: Text(
                    'RM ${o.total.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            EntrepreneurOrderDetailScreen(order: o),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Lukis "sparkline" ringkas dalam hero card (bukan chart sebenar)
class _SimpleSparklinePainter extends CustomPainter {
  final Color color;

  _SimpleSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final h = size.height;
    final w = size.width;

    path.moveTo(0, h * 0.7);
    path.quadraticBezierTo(w * 0.2, h * 0.2, w * 0.35, h * 0.5);
    path.quadraticBezierTo(w * 0.55, h * 0.9, w * 0.75, h * 0.4);
    path.quadraticBezierTo(w * 0.9, h * 0.2, w, h * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SimpleSparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// ===============================
/// ORDER DETAIL SCREEN + STATUS FLOW
/// ===============================

class EntrepreneurOrderDetailScreen extends StatefulWidget {
  final m.Order order;

  const EntrepreneurOrderDetailScreen({super.key, required this.order});

  @override
  State<EntrepreneurOrderDetailScreen> createState() =>
      _EntrepreneurOrderDetailScreenState();
}

class _EntrepreneurOrderDetailScreenState
    extends State<EntrepreneurOrderDetailScreen> {
  final _fs = FirestoreService();

  late String _status;
  Customer? _customer;
  bool _loadingCustomer = true;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final c =
        await _fs.getCustomerByOwner(widget.order.customerUid);
    if (!mounted) return;
    setState(() {
      _customer = c;
      _loadingCustomer = false;
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'processing':
        return 'Menunggu pengesahan';
      case 'accepted':
        return 'Disahkan';
      case 'ready':
        return 'Sedia untuk penghantaran';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status) {
      case 'processing':
        return Colors.orange;
      case 'accepted':
        return theme.colorScheme.primary;
      case 'ready':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.outline;
    }
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'processing':
        return 'accepted';
      case 'accepted':
        return 'ready';
      case 'ready':
        return 'completed';
      default:
        return null;
    }
  }

  String _nextStatusButtonLabel(String status) {
    switch (status) {
      case 'processing':
        return 'Terima pesanan';
      case 'accepted':
        return 'Tandakan sebagai sedia';
      case 'ready':
        return 'Tandakan pesanan selesai';
      default:
        return '';
    }
  }

  bool get _canCancel =>
      _status == 'processing' || _status == 'accepted';

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _updatingStatus = true);
    try {
      await _fs.updateOrderStatus(
        orderId: widget.order.id,
        newStatus: newStatus,
      );
      if (!mounted) return;
      setState(() {
        _status = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status pesanan dikemas kini ke "${_statusLabel(newStatus)}".',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal kemas kini status: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingStatus = false);
      }
    }
  }

  Future<void> _confirmAdvance() async {
    final ns = _nextStatus(_status);
    if (ns == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kemas kini status pesanan'),
        content: Text(
          'Status pesanan akan ditukar kepada "${_statusLabel(ns)}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sahkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _changeStatus(ns);
    }
  }

  Future<void> _confirmCancel() async {
    if (!_canCancel) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text(
          'Pesanan akan ditandakan sebagai dibatalkan. Pastikan anda telah memaklumkan pelanggan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan pesanan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _changeStatus('cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Butiran pesanan'),
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderSummaryHeader(
              order: order,
              status: _status,
              statusLabel: _statusLabel(_status),
              statusColor: _statusColor(context, _status),
            ),
            const SizedBox(height: 16),
            _StatusStepper(currentStatus: _status),
            const SizedBox(height: 16),
            if (_loadingCustomer)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              )
            else
              _CustomerInfoCard(customer: _customer),
            const SizedBox(height: 16),
            _OrderItemsCard(order: order),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Maklumat pelanggan diambil daripada profil pelanggan. '
                        'Anda boleh menghubungi pelanggan melalui nombor telefon atau alamat yang dipaparkan.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final ns = _nextStatus(_status);
    final showPrimary = ns != null;

    if (!showPrimary && !_canCancel) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              offset: Offset(0, -2),
              color: Colors.black12,
            ),
          ],
        ),
        child: Row(
          children: [
            if (_canCancel)
              TextButton(
                onPressed: _updatingStatus ? null : _confirmCancel,
                child: const Text(
                  'Batalkan pesanan',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const Spacer(),
            if (showPrimary)
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _updatingStatus ? null : _confirmAdvance,
                  child: _updatingStatus
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_nextStatusButtonLabel(_status)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Header card untuk ringkasan pesanan
class _OrderSummaryHeader extends StatelessWidget {
  final m.Order order;
  final String status;
  final String statusLabel;
  final Color statusColor;

  const _OrderSummaryHeader({
    required this.order,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan #${order.code}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.createdAtFormatted,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'RM ${order.total.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  final Customer? customer;

  const _CustomerInfoCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (customer == null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Maklumat pelanggan tidak ditemui.'),
        ),
      );
    }

    final p = customer!;
    ImageProvider? avatar;
    if (p.photoUrl.isNotEmpty) {
      avatar = NetworkImage(p.photoUrl);
    }
    final initial =
        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maklumat pelanggan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          p.email,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone,
              label: 'No. telefon',
              value: p.phone.isEmpty ? '-' : p.phone,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Alamat penghantaran',
              value:
                  p.address.isEmpty ? 'Tiada alamat' : p.address,
              multiLine: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment:
          multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  final m.Order order;

  const _OrderItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final subtotal = order.total; // belum ada shipping

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Butiran pesanan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...order.lines.map((line) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.productName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${line.quantity} x RM ${line.unitPrice.toStringAsFixed(2)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'RM ${line.lineTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jumlah bayaran',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'RM ${subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String currentStatus;

  const _StatusStepper({required this.currentStatus});

  int get _currentIndex {
    switch (currentStatus) {
      case 'processing':
        return 0;
      case 'accepted':
        return 1;
      case 'ready':
        return 2;
      case 'completed':
        return 3;
      case 'cancelled':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = _currentIndex;

    final labels = [
      'Menunggu',
      'Disahkan',
      'Sedia',
      'Selesai',
      'Batal',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status pesanan',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(labels.length, (i) {
            final active = i <= idx && !(idx == 4 && i < 4);
            final color = i == 4 && idx == 4
                ? theme.colorScheme.error
                : theme.colorScheme.primary;
            final circleColor =
                active ? color : theme.colorScheme.outline.withOpacity(0.4);

            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: circleColor,
                        ),
                      ),
                      if (i != labels.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 4),
                            color: i < idx
                                ? circleColor
                                : theme.colorScheme.outline
                                    .withOpacity(0.2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          active ? circleColor : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
