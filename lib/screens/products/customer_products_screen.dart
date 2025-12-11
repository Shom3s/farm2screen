import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/product.dart';
import '../../models/entrepreneur.dart';
import '../../services/cart_service.dart';
import '../../services/firestore_service.dart';

class CustomerProductsScreen extends StatefulWidget {
  const CustomerProductsScreen({super.key});

  @override
  State<CustomerProductsScreen> createState() =>
      _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerProductsScreen> {
  final _fs = FirestoreService();
  final _cart = CartService.instance;

  String _search = '';
  String? _selectedCategory; // null = semua

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk Nenas'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  user.email ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: _fs.productsForCustomer(),
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
              child: Text('Tiada produk buat masa ini.'),
            );
          }

          // Senarai kategori unik
          final categories = <String>{
            for (final p in products)
              if (p.category.trim().isNotEmpty) p.category.trim(),
          }.toList()
            ..sort();

          // Tapis produk ikut carian & kategori
          final filtered = products.where((p) {
            final matchSearch = _search.isEmpty ||
                p.name.toLowerCase().contains(_search.toLowerCase()) ||
                p.category.toLowerCase().contains(_search.toLowerCase());
            final matchCategory =
                _selectedCategory == null || p.category == _selectedCategory;
            return matchSearch && matchCategory;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari produk atau kategori…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _search = value);
                  },
                ),
              ),

              // Category chips
              if (categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ...categories.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: _selectedCategory == c,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory =
                                      _selectedCategory == c ? null : c;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Grid produk
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _ProductCard(
                      product: p,
                      onAddToCart: () => _cart.add(p),
                      onOpenDetail: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: p,
                              cartService: _cart,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;
  final VoidCallback onOpenDetail;

  const _ProductCard({
    required this.product,
    required this.onAddToCart,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;

    // Stock logic
    final bool inStock =
        product.available && (product.stockQty > 0); // needs stockQty field
    final bool isLowStock = inStock && product.stockQty <= 5;

    final String stockText =
        inStock ? 'Stok: ${product.stockQty} ${product.unit}' : 'Habis stok';
    final Color stockColor = inStock
        ? (isLowStock ? Colors.orangeAccent : theme.colorScheme.primary)
        : theme.colorScheme.error;

    return GestureDetector(
      onTap: onOpenDetail,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top image / icon area
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: hasImage
                            ? DecorationImage(
                                image: NetworkImage(product.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: hasImage
                            ? null
                            : LinearGradient(
                                colors: [
                                  theme.colorScheme.primary
                                      .withOpacity(0.12),
                                  theme.colorScheme.secondary
                                      .withOpacity(0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                      ),
                      child: !hasImage
                          ? const Center(
                              child: Icon(
                                Icons.local_grocery_store_outlined,
                                size: 40,
                              ),
                            )
                          : null,
                    ),
                    if (hasImage)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.25),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surface.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_border,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    // Extra: ribbon for low stock
                    if (isLowStock)
                      Positioned(
                        left: 0,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.95),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Stok rendah',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),

              Text(
                product.category.isNotEmpty ? product.category : 'Umum',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),

              // Stock row
              Text(
                stockText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: stockColor,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RM ${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '/ ${product.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: inStock ? onAddToCart : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: inStock
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 18,
                        color: inStock
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DETAIL SCREEN

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final CartService cartService;

  ProductDetailScreen({
    super.key,
    required this.product,
    required this.cartService,
  });

  final _fs = FirestoreService();

  Future<void> _launchUrlString(
      BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka pautan.')),
      );
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;

    final bool inStock =
        product.available && (product.stockQty > 0);
    final String stockText = inStock
        ? 'Stok tersedia: ${product.stockQty} ${product.unit}'
        : 'Habis stok buat masa ini';

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: FutureBuilder<Entrepreneur?>(
        future: _fs.getEntrepreneurByOwner(product.entrepreneurId),
        builder: (context, snapshot) {
          final seller = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 90, // space for bottom button
              top: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: hasImage
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary
                                      .withOpacity(0.15),
                                  theme.colorScheme.secondary
                                      .withOpacity(0.15),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.local_grocery_store_outlined,
                                size: 64,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name & category
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (product.category.isNotEmpty)
                      Chip(
                        label: Text(product.category),
                        visualDensity: VisualDensity.compact,
                      ),
                    const Spacer(),
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ ${product.unit}',
                      style: TextStyle(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Stock info
                Row(
                  children: [
                    Icon(
                      inStock
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: inStock
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      stockText,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: inStock
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Seller section
                if (seller != null) ...[
                  const Text(
                    'Dijual oleh',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: (seller.photoUrl != null &&
                              seller.photoUrl!.isNotEmpty)
                          ? NetworkImage(seller.photoUrl!)
                          : null,
                      child: (seller.photoUrl == null ||
                              seller.photoUrl!.isEmpty)
                          ? Text(
                              seller.name.isNotEmpty
                                  ? seller.name[0].toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    title: Text(
                      seller.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      seller.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SellerPublicProfileScreen(entrepreneur: seller),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  'Butiran produk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description.trim().isNotEmpty
                      ? product.description
                      : 'Tiada penerangan produk.',
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 24),

                if (seller != null) ...[
                  const Text(
                    'Lokasi jualan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (seller.farmLocation.isNotEmpty)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.agriculture),
                        title: const Text('Ladang'),
                        subtitle: Text(seller.farmLocation),
                        onTap: () =>
                            _openMap(context, seller.farmLocation),
                      ),
                    ),
                  if (seller.shopLocation.isNotEmpty)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.storefront),
                        title: const Text('Kedai'),
                        subtitle: Text(seller.shopLocation),
                        onTap: () =>
                            _openMap(context, seller.shopLocation),
                      ),
                    ),
                  const SizedBox(height: 16),

                  if ((seller.whatsappUrl?.isNotEmpty ?? false) ||
                      (seller.facebookUrl?.isNotEmpty ?? false) ||
                      (seller.instagramUrl?.isNotEmpty ?? false))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hubungi usahawan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (seller.whatsappUrl != null &&
                                seller.whatsappUrl!.isNotEmpty)
                              IconButton(
                                tooltip: 'WhatsApp',
                                onPressed: () => _launchUrlString(
                                    context, seller.whatsappUrl),
                                icon: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 22,
                                ),
                              ),
                            if (seller.facebookUrl != null &&
                                seller.facebookUrl!.isNotEmpty)
                              IconButton(
                                tooltip: 'Facebook',
                                onPressed: () => _launchUrlString(
                                    context, seller.facebookUrl),
                                icon: const FaIcon(
                                  FontAwesomeIcons.facebook,
                                  size: 22,
                                ),
                              ),
                            if (seller.instagramUrl != null &&
                                seller.instagramUrl!.isNotEmpty)
                              IconButton(
                                tooltip: 'Instagram',
                                onPressed: () => _launchUrlString(
                                    context, seller.instagramUrl),
                                icon: const FaIcon(
                                  FontAwesomeIcons.instagram,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: inStock
                  ? () {
                      cartService.add(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Produk ditambah ke troli.'),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(inStock ? 'Tambah ke troli' : 'Habis stok'),
            ),
          ),
        ),
      ),
    );
  }
}

/// PUBLIC VIEW OF ENTREPRENEUR FOR CUSTOMER

class SellerPublicProfileScreen extends StatelessWidget {
  final Entrepreneur entrepreneur;

  const SellerPublicProfileScreen({
    super.key,
    required this.entrepreneur,
  });

  Future<void> _launchUrlString(
      BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka pautan.')),
      );
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = entrepreneur;

    ImageProvider? avatarImage;
    if (p.photoUrl != null && p.photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(p.photoUrl!);
    }
    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

    final hasAnySocial = (p.whatsappUrl?.isNotEmpty ?? false) ||
        (p.facebookUrl?.isNotEmpty ?? false) ||
        (p.instagramUrl?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Usahawan'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.phone,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasAnySocial) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (p.whatsappUrl != null &&
                            p.whatsappUrl!.isNotEmpty)
                          IconButton(
                            tooltip: 'WhatsApp',
                            onPressed: () =>
                                _launchUrlString(context, p.whatsappUrl),
                            icon: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 20,
                            ),
                          ),
                        if (p.facebookUrl != null &&
                            p.facebookUrl!.isNotEmpty)
                          IconButton(
                            tooltip: 'Facebook',
                            onPressed: () =>
                                _launchUrlString(context, p.facebookUrl),
                            icon: const FaIcon(
                              FontAwesomeIcons.facebook,
                              size: 20,
                            ),
                          ),
                        if (p.instagramUrl != null &&
                            p.instagramUrl!.isNotEmpty)
                          IconButton(
                            tooltip: 'Instagram',
                            onPressed: () =>
                                _launchUrlString(context, p.instagramUrl),
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        p.farmLocation.isEmpty
                            ? 'Tidak dinyatakan'
                            : p.farmLocation,
                      ),
                      onTap: () => _openMap(context, p.farmLocation),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.storefront),
                      title: const Text('Kedai'),
                      subtitle: Text(
                        p.shopLocation.isEmpty
                            ? 'Tidak dinyatakan'
                            : p.shopLocation,
                      ),
                      onTap: () => _openMap(context, p.shopLocation),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    children: p.productCategories.isEmpty
                        ? const [Text('Tiada kategori ditetapkan.')]
                        : p.productCategories
                            .map((c) => Chip(label: Text(c)))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Penerangan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.description.isEmpty
                        ? 'Tiada penerangan.'
                        : p.description,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
