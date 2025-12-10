import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/entrepreneur.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/firestore_service.dart';
// use existing customer product detail file
import '../products/customer_products_screen.dart';

class CustomerEntrepreneurSearchScreen extends StatefulWidget {
  const CustomerEntrepreneurSearchScreen({super.key});

  @override
  State<CustomerEntrepreneurSearchScreen> createState() =>
      _CustomerEntrepreneurSearchScreenState();
}

class _CustomerEntrepreneurSearchScreenState
    extends State<CustomerEntrepreneurSearchScreen> {
  final _fs = FirestoreService();

  String _search = '';
  String _selectedCategory = 'Semua';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usahawan Nenas'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            // Search field
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari usahawan, lokasi atau kategori…',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            // Stream of entrepreneurs
            Expanded(
              child: StreamBuilder<List<Entrepreneur>>(
                stream: _fs.entrepreneursStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Ralat memuatkan usahawan.'),
                    );
                  }

                  final all = snapshot.data ?? [];

                  // Build category list from all entrepreneurs
                  final categorySet = <String>{};
                  for (final e in all) {
                    for (final c in e.productCategories) {
                      if (c.trim().isNotEmpty) {
                        categorySet.add(c.trim());
                      }
                    }
                  }
                  final categories = ['Semua', ...categorySet.toList()];

                  // Apply search + category filter
                  final query = _search.toLowerCase();
                  final filtered = all.where((e) {
                    final matchesQuery = query.isEmpty
                        ? true
                        : e.name.toLowerCase().contains(query) ||
                            e.farmLocation.toLowerCase().contains(query) ||
                            e.shopLocation.toLowerCase().contains(query) ||
                            e.productCategories.any(
                              (c) => c.toLowerCase().contains(query),
                            );

                    final matchesCategory = _selectedCategory == 'Semua'
                        ? true
                        : e.productCategories.any(
                            (c) => c.toLowerCase() ==
                                _selectedCategory.toLowerCase(),
                          );

                    return matchesQuery && matchesCategory;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryChips(categories, theme),
                        const SizedBox(height: 24),
                        const Center(
                          child: Text('Tiada usahawan dijumpai.'),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryChips(categories, theme),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final e = filtered[index];
                            return _EntrepreneurCard(entrepreneur: e);
                          },
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

  Widget _buildCategoryChips(List<String> categories, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final selected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EntrepreneurCard extends StatelessWidget {
  final Entrepreneur entrepreneur;

  const _EntrepreneurCard({required this.entrepreneur});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameInitial =
        entrepreneur.name.isNotEmpty ? entrepreneur.name[0].toUpperCase() : '?';

    ImageProvider? avatarImage;
    if (entrepreneur.photoUrl != null &&
        entrepreneur.photoUrl!.trim().isNotEmpty) {
      avatarImage = NetworkImage(entrepreneur.photoUrl!);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerEntrepreneurDetailScreen(
              entrepreneur: entrepreneur,
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        nameInitial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entrepreneur.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (entrepreneur.shopLocation.isNotEmpty)
                      Text(
                        entrepreneur.shopLocation,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (entrepreneur.farmLocation.isNotEmpty)
                      Text(
                        entrepreneur.farmLocation,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: entrepreneur.productCategories.isEmpty
                          ? [
                              Chip(
                                label: const Text('Tiada kategori'),
                                backgroundColor: theme
                                    .colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                              ),
                            ]
                          : entrepreneur.productCategories
                              .map(
                                (c) => Chip(
                                  label: Text(c),
                                  backgroundColor:
                                      theme.colorScheme.surfaceVariant,
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paparan penuh biodata usahawan + senarai produk yang dijual.
class CustomerEntrepreneurDetailScreen extends StatelessWidget {
  final Entrepreneur entrepreneur;
  CustomerEntrepreneurDetailScreen({super.key, required this.entrepreneur});

  final _fs = FirestoreService();
  final _cart = CartService.instance;

  // Launch external URLs (WhatsApp, FB, IG)
  Future<void> _launchUrlString(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka pautan.')),
      );
    }
  }

  // OPEN GOOGLE MAPS FOR ADDRESS
  Future<void> _openMap(BuildContext context, String address) async {
    if (address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat tidak dinyatakan.')),
      );
      return;
    }

    final query = Uri.encodeComponent(address.trim());
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameInitial =
        entrepreneur.name.isNotEmpty ? entrepreneur.name[0].toUpperCase() : '?';

    ImageProvider? avatarImage;
    if (entrepreneur.photoUrl != null &&
        entrepreneur.photoUrl!.trim().isNotEmpty) {
      avatarImage = NetworkImage(entrepreneur.photoUrl!);
    }

    final hasAnySocial = (entrepreneur.whatsappUrl?.isNotEmpty ?? false) ||
        (entrepreneur.facebookUrl?.isNotEmpty ?? false) ||
        (entrepreneur.instagramUrl?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(entrepreneur.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header biodata (match Profil Usahawan style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        nameInitial,
                        style: const TextStyle(
                          fontSize: 32,
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
                      entrepreneur.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (entrepreneur.email.isNotEmpty)
                      Text(
                        entrepreneur.email,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (entrepreneur.phone.isNotEmpty)
                      Text(
                        entrepreneur.phone,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (hasAnySocial) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (entrepreneur.whatsappUrl != null &&
                              entrepreneur.whatsappUrl!.isNotEmpty)
                            IconButton(
                              tooltip: 'WhatsApp',
                              onPressed: () => _launchUrlString(
                                  context, entrepreneur.whatsappUrl),
                              icon: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 20,
                              ),
                            ),
                          if (entrepreneur.facebookUrl != null &&
                              entrepreneur.facebookUrl!.isNotEmpty)
                            IconButton(
                              tooltip: 'Facebook',
                              onPressed: () => _launchUrlString(
                                  context, entrepreneur.facebookUrl),
                              icon: const FaIcon(
                                FontAwesomeIcons.facebook,
                                size: 20,
                              ),
                            ),
                          if (entrepreneur.instagramUrl != null &&
                              entrepreneur.instagramUrl!.isNotEmpty)
                            IconButton(
                              tooltip: 'Instagram',
                              onPressed: () => _launchUrlString(
                                  context, entrepreneur.instagramUrl),
                              icon: const FaIcon(
                                FontAwesomeIcons.instagram,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Lokasi cards (similar to Profil Usahawan)
          const Text(
            'Lokasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.agriculture),
              title: const Text('Ladang'),
              subtitle: Text(
                entrepreneur.farmLocation.isEmpty
                    ? 'Tidak dinyatakan'
                    : entrepreneur.farmLocation,
              ),
              onTap: () => _openMap(context, entrepreneur.farmLocation),
            ),
          ),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Kedai'),
              subtitle: Text(
                entrepreneur.shopLocation.isEmpty
                    ? 'Tidak dinyatakan'
                    : entrepreneur.shopLocation,
              ),
              onTap: () => _openMap(context, entrepreneur.shopLocation),
            ),
          ),
          const SizedBox(height: 16),

          // Kategori produk
          const Text(
            'Kategori produk',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entrepreneur.productCategories.isEmpty
                ? const [Text('Tiada kategori ditetapkan.')]
                : entrepreneur.productCategories
                    .map((c) => Chip(label: Text(c)))
                    .toList(),
          ),
          const SizedBox(height: 16),

          // Penerangan
          const Text(
            'Penerangan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entrepreneur.description.isEmpty
                ? 'Tiada penerangan.'
                : entrepreneur.description,
          ),
          const SizedBox(height: 24),

          // Senarai produk
          const Text(
            'Produk yang dijual',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Product>>(
            // gunakan ownerUid (Firebase Auth user id)
            stream: _fs.productsForEntrepreneur(entrepreneur.ownerUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Ralat memuatkan produk usahawan.'),
                );
              }

              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Usahawan ini belum menambah produk.'),
                );
              }

              return Column(
                children: products.map((p) {
                  ImageProvider? image;
                  if (p.imageUrl != null &&
                      p.imageUrl!.trim().isNotEmpty) {
                    image = NetworkImage(p.imageUrl!);
                  }

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            product: p,
                            cartService: _cart,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: image != null
                                    ? Image(
                                        image: image,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: theme
                                            .colorScheme.surfaceVariant,
                                        child: const Icon(
                                          Icons.local_mall_outlined,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'RM ${p.price.toStringAsFixed(2)} / ${p.unit}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (p.category.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      p.category,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
