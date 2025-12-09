import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../services/firestore_service.dart';

class CartScreen extends StatelessWidget {
  final CartService cartService;

  CartScreen({super.key, required this.cartService});

  final _fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartService,
      builder: (context, _) {
        final items = cartService.items;

        if (items.isEmpty) {
          return const Center(
            child: Text('Troli kosong.'),
          );
        }

        return SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Troli',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${items.length} item',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CartItemTile(
                      item: item,
                      onIncrease: () => cartService.add(item.product),
                      onDecrease: () => cartService.decrease(item.product),
                      onRemove: () => cartService.remove(item.product),
                    );
                  },
                ),
              ),

              // Bottom bar
              _CartBottomBar(
                total: cartService.total,
                onCheckout: () => _checkout(context, items),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkout(BuildContext context, List<CartItem> items) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila log masuk semula.')),
      );
      return;
    }
    if (items.isEmpty) return;

    final firstEntrepreneurId = items.first.product.entrepreneurId;

    // Buka halaman checkout penuh
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CheckoutScreen(
          items: List<CartItem>.from(items),
          total: cartService.total,
          customerUid: user.uid,
          entrepreneurId: firstEntrepreneurId,
          firestore: _fs,
          cartService: cartService,
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage =
        item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(item.product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasImage
                  ? const Icon(Icons.local_grocery_store_outlined)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${item.product.price.toStringAsFixed(2)} / ${item.product.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(item.quantity.toString()),
            IconButton(
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBottomBar extends StatelessWidget {
  final double total;
  final VoidCallback onCheckout;

  const _CartBottomBar({
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, -2),
              color: Colors.black12,
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jumlah bayaran',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'RM ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onCheckout,
                  child: const Text('Teruskan pembayaran'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==================
/// Checkout Screen
/// ==================

class _CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final double total;
  final String customerUid;
  final String entrepreneurId;
  final FirestoreService firestore;
  final CartService cartService;

  const _CheckoutScreen({
    required this.items,
    required this.total,
    required this.customerUid,
    required this.entrepreneurId,
    required this.firestore,
    required this.cartService,
  });

  @override
  State<_CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<_CheckoutScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _paymentMethod = 'cod'; // 'cod' | 'online'
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
    _phoneCtrl.text = '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      // Di sini anda boleh sambung integrasi payment gateway sebenar
      // (ToyyibPay / Billplz / Stripe dll).
      // Buat masa ini kita anggap bayaran COD dan terus rekod pesanan.

      final lines = widget.cartService.toOrderLines();

      await widget.firestore.createOrder(
        customerUid: widget.customerUid,
        entrepreneurId: widget.entrepreneurId,
        lines: lines,
      );

      widget.cartService.clear();

      if (!mounted) return;
      Navigator.of(context).pop(); // balik ke troli
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berjaya dihantar. Terima kasih!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat pesanan: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Ringkasan pesanan'),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...items.map((i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${i.quantity}x ${i.product.name}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  'RM ${i.lineTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(),
                        _AmountRow(
                          label: 'Subjumlah',
                          value:
                              'RM ${widget.total.toStringAsFixed(2)}',
                        ),
                        const _AmountRow(
                          label: 'Caj penghantaran',
                          value: 'RM 0.00',
                        ),
                        const SizedBox(height: 4),
                        _AmountRow(
                          label: 'Jumlah bayaran',
                          value:
                              'RM ${widget.total.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const _SectionTitle('Maklumat penerima'),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama penuh',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Masukkan nama'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'No. telefon',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Masukkan no. telefon'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText:
                                'Catatan untuk usahawan (pilihan)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const _SectionTitle('Kaedah pembayaran'),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'cod',
                        groupValue: _paymentMethod,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _paymentMethod = v);
                        },
                        title:
                            const Text('Bayar semasa ambil / COD'),
                        subtitle: const Text(
                          'Bayar terus kepada usahawan semasa pickup atau penghantaran.',
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: theme.dividerColor.withOpacity(0.5),
                      ),
                      RadioListTile<String>(
                        value: 'online',
                        groupValue: _paymentMethod,
                        onChanged: null, // belum diaktifkan
                        title: const Text(
                          'Bayaran online (akan datang)',
                        ),
                        subtitle: const Text(
                          'Integrasi FPX / kad debit & kredit boleh ditambah kemudian.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _confirmOrder,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Sahkan pesanan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _AmountRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

