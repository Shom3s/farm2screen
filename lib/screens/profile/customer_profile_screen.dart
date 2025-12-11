import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/customer.dart';
import '../../models/order.dart' as m; // NEW
import '../../services/firestore_service.dart';
import '../../services/supabase_storage_service.dart';
import '../auth/login_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _storage = SupabaseStorageService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  // Tukar kata laluan
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _passwordError;
  bool _passwordSaving = false;

  bool _loading = true;
  bool _editMode = true;
  String? _error;
  Customer? _currentProfile;

  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Pengguna tidak ditemui.';
      });
      return;
    }

    final profile = await _fs.getCustomerByOwner(user.uid);

    if (profile != null) {
      _currentProfile = profile;
      _editMode = false;
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _addressController.text = profile.address;
    } else {
      _editMode = true;
      _emailController.text = user.email ?? '';
    }

    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImageIfNeeded(String userId) async {
    if (_selectedImageFile == null) {
      return _currentProfile?.photoUrl;
    }
    try {
      final url = await _storage.uploadProfileImage(
        _selectedImageFile!,
        'customer_$userId',
      );
      return url;
    } catch (e) {
      throw Exception('Gagal memuat naik gambar: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final photoUrl = await _uploadImageIfNeeded(user.uid);

      final profile = Customer(
        id: _currentProfile?.id ?? '',
        ownerUid: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        photoUrl: photoUrl ?? '',
      );

      await _fs.upsertCustomer(profile);
      _currentProfile = profile;

      if (!mounted) return;
      setState(() {
        _editMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil pelanggan berjaya disimpan.'),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    // reset state every time dialog opens
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _passwordError = null;
    _passwordSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Tukar kata laluan'),
              content: Form(
                key: _passwordFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _currentPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Kata laluan semasa',
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Masukkan kata laluan semasa'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Kata laluan baharu',
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Masukkan kata laluan baharu';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 aksara';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Sahkan kata laluan baharu',
                        ),
                        obscureText: true,
                        validator: (v) =>
                            v != _newPasswordController.text
                                ? 'Kata laluan tidak sepadan'
                                : null,
                      ),
                      if (_passwordError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _passwordError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      _passwordSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: _passwordSaving
                      ? null
                      : () async {
                          if (!_passwordFormKey.currentState!.validate()) {
                            return;
                          }
                          setStateDialog(() {
                            _passwordSaving = true;
                            _passwordError = null;
                          });

                          try {
                            final cred = EmailAuthProvider.credential(
                              email: user.email!,
                              password:
                                  _currentPasswordController.text.trim(),
                            );
                            await user.reauthenticateWithCredential(cred);
                            await user.updatePassword(
                              _newPasswordController.text.trim(),
                            );

                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Kata laluan berjaya dikemas kini.'),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            setStateDialog(() {
                              _passwordSaving = false;
                              if (e.code == 'wrong-password') {
                                _passwordError =
                                    'Kata laluan semasa tidak tepat.';
                              } else if (e.code == 'weak-password') {
                                _passwordError =
                                    'Kata laluan baharu terlalu lemah.';
                              } else {
                                _passwordError =
                                    'Ralat: ${e.message ?? e.code}';
                              }
                            });
                          } catch (_) {
                            setStateDialog(() {
                              _passwordSaving = false;
                              _passwordError = 'Ralat tidak dijangka.';
                            });
                          }
                        },
                  child: _passwordSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pelanggan'),
        actions: [
          IconButton(
            tooltip: 'Log keluar',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _editMode
              ? _buildEditForm()
              : _buildProfileView(), // read-only view with purchases
    );
  }

  // ---------- Edit form ----------

  Widget _buildEditForm() {
    final initialLetter = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';

    ImageProvider? avatarImage;
    if (_selectedImageFile != null) {
      avatarImage = FileImage(_selectedImageFile!);
    } else if (_currentProfile?.photoUrl.isNotEmpty == true) {
      avatarImage = NetworkImage(_currentProfile!.photoUrl);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Maklumat ini digunakan semasa membuat pesanan.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              initialLetter,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.95),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const CircleAvatar(
                        radius: 14,
                        child: Icon(Icons.camera_alt, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Nama penuh'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan nama' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration:
                  const InputDecoration(labelText: 'No. telefon'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan telefon' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Alamat penghantaran',
              ),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Simpan profil'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Read-only view + purchases ----------

  Widget _buildProfileView() {
    final p = _currentProfile;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Sesi tamat. Sila log masuk semula.'),
      );
    }

    if (p == null) {
      _editMode = true;
      return _buildEditForm();
    }

    return StreamBuilder<List<m.Order>>(
      stream: _fs.ordersForCustomer(user.uid),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? <m.Order>[];

        final totalSpent =
            orders.fold<double>(0, (sum, o) => sum + o.total);
        final totalOrders = orders.length;
        final avgOrder =
            totalOrders == 0 ? 0.0 : totalSpent / totalOrders;

        orders.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );
        final lastOrder = orders.isNotEmpty ? orders.first : null;

        ImageProvider? avatarImage;
        if (p.photoUrl.isNotEmpty) {
          avatarImage = NetworkImage(p.photoUrl);
        }
        final initial =
            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

        return CustomScrollView(
          slivers: [
            // Header + basic profile
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
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
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (p.email.isNotEmpty)
                                Text(
                                  p.email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _editMode = true);
                            },
                            child: const Text('Kemaskini profil'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _showChangePasswordDialog,
                            child: const Text('Tukar kata laluan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Contact info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maklumat hubungan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.phone),
                            title: Text(
                              p.phone.isEmpty ? '-' : p.phone,
                            ),
                          ),
                          const Divider(height: 0),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.home),
                            title: const Text('Alamat'),
                            subtitle: Text(
                              p.address.isEmpty
                                  ? 'Tiada alamat'
                                  : p.address,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Purchase summary card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _PurchaseSummaryCard(
                  totalSpent: totalSpent,
                  totalOrders: totalOrders,
                  avgOrder: avgOrder,
                  lastOrder: lastOrder,
                ),
              ),
            ),

            // Orders list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _OrdersListCard(orders: orders),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ringkasan pembelian: jumlah dibelanjakan, jumlah pesanan, purata dan last order.
class _PurchaseSummaryCard extends StatelessWidget {
  final double totalSpent;
  final int totalOrders;
  final double avgOrder;
  final m.Order? lastOrder;

  const _PurchaseSummaryCard({
    required this.totalSpent,
    required this.totalOrders,
    required this.avgOrder,
    required this.lastOrder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = 'RM ${totalSpent.toStringAsFixed(2)}';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.95),
              theme.colorScheme.primaryContainer,
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
              'Ringkasan pembelian',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              amountText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              totalOrders == 0
                  ? 'Belum ada pesanan'
                  : '$totalOrders pesanan dibuat',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryChip(
                  label: 'Purata setiap pesanan',
                  value: 'RM ${avgOrder.toStringAsFixed(2)}',
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Pesanan terakhir',
                  value: lastOrder == null
                      ? '-'
                      : lastOrder!.createdAtFormatted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.onPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Senarai pesanan + produk yang dibeli
class _OrdersListCard extends StatelessWidget {
  final List<m.Order> orders;

  const _OrdersListCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  'Sejarah pembelian',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  orders.isEmpty ? '' : '${orders.length} pesanan',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Anda belum membuat sebarang pesanan.',
                ),
              )
            else
              ...orders.map((o) {
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding:
                      const EdgeInsets.only(bottom: 8, left: 0, right: 0),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.08),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    'Pesanan #${o.code.isEmpty ? o.id.substring(0, 6) : o.code}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${o.createdAtFormatted} • RM ${o.total.toStringAsFixed(2)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  children: [
                    Column(
                      children: o.lines.map((line) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.circle,
                            size: 8,
                          ),
                          title: Text(
                            line.productName,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            '${line.quantity} x RM ${line.unitPrice.toStringAsFixed(2)}',
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          trailing: Text(
                            'RM ${line.lineTotal.toStringAsFixed(2)}',
                            style:
                                theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}
