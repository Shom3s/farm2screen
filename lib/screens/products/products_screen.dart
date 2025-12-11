import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product.dart';
import '../../services/firestore_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _fs = FirestoreService();

  String get _entrepreneurId => FirebaseAuth.instance.currentUser!.uid;

  // UI state
  String _statusFilter = 'Semua'; // Semua, Aktif, Habis stok
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Produk Saya'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Produk baharu'),
        elevation: 6,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar (OUTSIDE StreamBuilder)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Cari produk…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchCtrl.clear();
                                });
                                _searchFocusNode.requestFocus();
                              },
                            ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Filter chips (also OUTSIDE StreamBuilder)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _statusFilter == 'Semua',
                    onTap: () => setState(() {
                      _statusFilter = 'Semua';
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Aktif',
                    selected: _statusFilter == 'Aktif',
                    onTap: () => setState(() {
                      _statusFilter = 'Aktif';
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Habis stok',
                    selected: _statusFilter == 'Habis stok',
                    onTap: () => setState(() {
                      _statusFilter = 'Habis stok';
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Everything that depends on Firestore stream
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _fs.productsForEntrepreneur(_entrepreneurId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Ralat memuatkan produk:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final products = snapshot.data ?? <Product>[];

                  // Stats
                  final totalItems = products.length;
                  final activeItems =
                      products.where((p) => p.inStock).length;
                  final outOfStockItems =
                      products.where((p) => !p.inStock).length;
                  final stockValue = products.fold<double>(
                    0,
                    (sum, p) => sum + (p.price * p.stockQty),
                  );

                  // Filtering (uses state from outside)
                  final q = _searchQuery.trim().toLowerCase();
                  final filtered = products.where((p) {
                    final matchesStatus = switch (_statusFilter) {
                      'Aktif' => p.inStock,
                      'Habis stok' => !p.inStock,
                      _ => true,
                    };

                    final name = p.name.toLowerCase();
                    final category = p.category.toLowerCase();
                    final matchesSearch =
                        q.isEmpty || name.contains(q) || category.contains(q);

                    return matchesStatus && matchesSearch;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header + stats
                      Text(
                        'Ringkasan produk ($totalItems)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryChip(
                              label: 'Produk aktif',
                              value: '$activeItems',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryChip(
                              label: 'Habis stok',
                              value: '$outOfStockItems',
                              icon: Icons.error_outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SummaryChip(
                              label: 'Nilai stok',
                              value: 'RM ${stockValue.toStringAsFixed(2)}',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // List / empty / no results
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: products.isEmpty
                              ? _EmptyProductsState(
                                  key: const ValueKey('empty_state'),
                                  onAddTap: () => _openProductForm(context),
                                )
                              : filtered.isEmpty
                                  ? _NoResultsState(
                                      key:
                                          const ValueKey('no_results_state'),
                                      resetFilters: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _searchCtrl.clear();
                                          _statusFilter = 'Semua';
                                        });
                                        _searchFocusNode.requestFocus();
                                      },
                                    )
                                  : ListView.separated(
                                      key: const ValueKey('product_list'),
                                      padding:
                                          const EdgeInsets.only(bottom: 80),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final p = filtered[index];
                                        return Dismissible(
                                          key: ValueKey(p.id),
                                          direction:
                                              DismissDirection.endToStart,
                                          background:
                                              _buildDeleteBackground(context),
                                          confirmDismiss: (_) =>
                                              _confirmDelete(
                                                  context, p.name),
                                          onDismissed: (_) {
                                            _fs.deleteProduct(p.id);
                                          },
                                          child: _EntrepreneurProductCard(
                                            product: p,
                                            onEdit: () => _openProductForm(
                                              context,
                                              product: p,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.error.withOpacity(0.25),
            theme.colorScheme.error,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(
        Icons.delete_outline,
        color: Colors.white,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam produk'),
        content: Text('Anda pasti mahu memadam "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
  }

  void _openProductForm(BuildContext context, {Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final categoryCtrl =
        TextEditingController(text: product?.category ?? '');
    final priceCtrl = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(2) : '',
    );
    final unitCtrl = TextEditingController(text: product?.unit ?? 'unit');
    final stockCtrl = TextEditingController(
      text: product != null ? product.stockQty.toString() : '',
    );

    final formKey = GlobalKey<FormState>();

    File? selectedImageFile;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final picked =
                  await picker.pickImage(source: ImageSource.gallery);
              if (picked != null) {
                setModalState(() {
                  selectedImageFile = File(picked.path);
                });
              }
            }

            Future<void> saveProduct() async {
              if (!formKey.currentState!.validate() || saving) return;

              setModalState(() {
                saving = true;
              });

              final price =
                  double.parse(priceCtrl.text.replaceAll(',', '.'));
              final stockQty = int.tryParse(stockCtrl.text) ?? 0;

              String? imageUrl = product?.imageUrl;

              try {
                if (selectedImageFile != null) {
                  final client = Supabase.instance.client;
                  const bucketName = 'product-pictures';

                  final path =
                      '$_entrepreneurId/${DateTime.now().millisecondsSinceEpoch}.jpg';

                  await client.storage.from(bucketName).upload(
                        path,
                        selectedImageFile!,
                        fileOptions: const FileOptions(
                          cacheControl: '3600',
                          upsert: false,
                        ),
                      );

                  imageUrl =
                      client.storage.from(bucketName).getPublicUrl(path);
                }

                if (product == null) {
                  final p = Product(
                    id: '',
                    entrepreneurId: _entrepreneurId,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    category: categoryCtrl.text.trim(),
                    price: price,
                    unit: unitCtrl.text.trim().isEmpty
                        ? 'unit'
                        : unitCtrl.text.trim(),
                    imageUrl: imageUrl,
                    available: true,
                    createdAt: DateTime.now(),
                    stockQty: stockQty,
                  );
                  await _fs.addProduct(p);
                } else {
                  final updated = Product(
                    id: product.id,
                    entrepreneurId: product.entrepreneurId,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    category: categoryCtrl.text.trim(),
                    price: price,
                    unit: unitCtrl.text.trim().isEmpty
                        ? 'unit'
                        : unitCtrl.text.trim(),
                    imageUrl: imageUrl,
                    available: product.available,
                    createdAt: product.createdAt,
                    stockQty: stockQty,
                  );
                  await _fs.updateProduct(updated);
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                setModalState(() {
                  saving = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menyimpan produk: $e'),
                  ),
                );
              }
            }

            final theme = Theme.of(context);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mediaQuery.viewInsets.bottom + 16,
                top: 12,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product == null
                                  ? 'Produk baharu'
                                  : 'Kemaskini produk',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Image picker
                      GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          height: 170,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.2),
                            image: selectedImageFile != null
                                ? DecorationImage(
                                    image: FileImage(selectedImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : (product?.imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            product!.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                          child: (selectedImageFile == null &&
                                  product?.imageUrl == null)
                              ? Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_a_photo_outlined),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tambah gambar produk',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Maklumat asas',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama produk',
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Masukkan nama produk'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kategori (contoh: Jus, Buah segar)',
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Harga & unit',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: priceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Harga (RM)',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Masukkan harga';
                                }
                                final d = double.tryParse(
                                  v.replaceAll(',', '.'),
                                );
                                if (d == null) {
                                  return 'Format nombor tidak sah';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: unitCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Unit (contoh: botol, kg)',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Inventori',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: stockCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kuantiti stok (contoh: 20)',
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Penerangan',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Penerangan ringkas',
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: saving ? null : saveProduct,
                          child: saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  product == null
                                      ? 'Simpan produk'
                                      : 'Kemaskini produk',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Summary stat chip
class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
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

/// Filter chip used for status filter
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color:
            selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Product card (refined layout)
class _EntrepreneurProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;

  const _EntrepreneurProductCard({
    required this.product,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage =
        product.imageUrl != null && product.imageUrl!.isNotEmpty;

    final stockText = product.inStock
        ? 'Stok: ${product.stockQty} ${product.unit}'
        : 'Habis stok';
    final stockColor =
        product.inStock ? theme.colorScheme.primary : theme.colorScheme.error;

    final badgeColor = product.inStock
        ? theme.colorScheme.primary.withOpacity(0.12)
        : theme.colorScheme.error.withOpacity(0.12);
    final badgeTextColor =
        product.inStock ? theme.colorScheme.primary : theme.colorScheme.error;
    final badgeLabel = product.inStock ? 'Aktif' : 'Habis stok';

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.25),
                  image: hasImage
                      ? DecorationImage(
                          image: NetworkImage(product.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasImage
                    ? Icon(
                        Icons.local_grocery_store_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: name + status badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: badgeTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Price
                    Text(
                      'RM ${product.price.toStringAsFixed(2)} / ${product.unit}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // Category
                    Text(
                      product.category.isNotEmpty
                          ? product.category
                          : 'Tiada kategori',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Stock row
                    Row(
                      children: [
                        Icon(
                          product.inStock
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 14,
                          color: stockColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stockText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: stockColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Edit icon
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onEdit,
                tooltip: 'Kemaskini produk',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final VoidCallback onAddTap;

  const _EmptyProductsState({
    super.key,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada produk',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Mula dengan menambah produk pertama anda. '
              'Gambar yang jelas dan harga yang tepat akan membantu menarik pelanggan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add),
              label: const Text('Tambah produk baharu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final VoidCallback resetFilters;

  const _NoResultsState({
    super.key,
    required this.resetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Tiada produk sepadan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tiada produk ditemui untuk carian dan penapis semasa.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: resetFilters,
              child: const Text('Set semula carian & penapis'),
            ),
          ],
        ),
      ),
    );
  }
}
