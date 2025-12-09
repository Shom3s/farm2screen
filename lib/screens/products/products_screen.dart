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

  String get _entrepreneurId =>
      FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk Saya'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Produk baharu'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _fs.productsForEntrepreneur(_entrepreneurId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Ralat memuatkan produk: ${snapshot.error}'),
            );
          }

          final products = snapshot.data ?? <Product>[];
          if (products.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada produk. Tambah produk pertama anda.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Dismissible(
                key: ValueKey(p.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Padam produk'),
                          content:
                              Text('Anda pasti mahu memadam "${p.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              child: const Text('Padam'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) {
                  _fs.deleteProduct(p.id);
                },
                child: _EntrepreneurProductCard(
                  product: p,
                  onEdit: () => _openProductForm(context, product: p),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openProductForm(BuildContext context, {Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl =
        TextEditingController(text: product?.description ?? '');
    final categoryCtrl =
        TextEditingController(text: product?.category ?? '');
    final priceCtrl = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(2) : '',
    );
    final unitCtrl = TextEditingController(text: product?.unit ?? 'unit');

    final formKey = GlobalKey<FormState>();

    File? selectedImageFile;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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

              String? imageUrl = product?.imageUrl;

              try {
                // Upload ke Supabase jika ada gambar baru
                if (selectedImageFile != null) {
                  final client = Supabase.instance.client;

                  const bucketName = 'product-pictures'; // BUCKET BARU

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

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product == null
                            ? 'Produk baharu'
                            : 'Kemaskini produk',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PICK / PREVIEW IMAGE
                      GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          height: 170,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.surfaceVariant
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

                      const SizedBox(height: 16),
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
                      const SizedBox(height: 8),
                      TextFormField(
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
                          final d =
                              double.tryParse(v.replaceAll(',', '.'));
                          if (d == null) return 'Format nombor tidak sah';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unit (contoh: botol, kg)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Penerangan ringkas',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                                      ? 'Simpan'
                                      : 'Kemaskini',
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
                image: product.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrl == null
                  ? const Icon(Icons.local_grocery_store_outlined)
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${product.price.toStringAsFixed(2)} / ${product.unit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category.isNotEmpty
                        ? product.category
                        : 'Tiada kategori',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
