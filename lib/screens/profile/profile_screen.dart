import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/entrepreneur.dart';
import '../../services/firestore_service.dart';
import '../../services/supabase_storage_service.dart';
import '../auth/login_screen.dart';
import '../../theme_controller.dart'; // <— NEW

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _storage = SupabaseStorageService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _farmController = TextEditingController();
  final _shopController = TextEditingController();
  final _descController = TextEditingController();
  final _categoriesController = TextEditingController();

  // Media sosial
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();

  bool _loading = true;
  bool _editMode = true;
  String? _error;
  Entrepreneur? _currentProfile;
  File? _selectedImageFile;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sesi tamat.';
      });
      return;
    }

    final profile = await _fs.getEntrepreneurByOwner(user.uid);
    if (profile != null) {
      _currentProfile = profile;
      _editMode = false;

      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _farmController.text = profile.farmLocation;
      _shopController.text = profile.shopLocation;
      _descController.text = profile.description;
      _categoriesController.text =
          profile.productCategories.join(', ');

      _whatsappController.text = profile.whatsappUrl ?? '';
      _facebookController.text = profile.facebookUrl ?? '';
      _instagramController.text = profile.instagramUrl ?? '';
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
    return _storage.uploadProfileImage(_selectedImageFile!, userId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _user;
    if (user == null) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final categories = _categoriesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final photoUrl = await _uploadImageIfNeeded(user.uid);

      final profile = Entrepreneur(
        id: _currentProfile?.id ?? '',
        ownerUid: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        farmLocation: _farmController.text.trim(),
        shopLocation: _shopController.text.trim(),
        description: _descController.text.trim(),
        productCategories: categories,
        photoUrl: photoUrl,
        whatsappUrl: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        facebookUrl: _facebookController.text.trim().isEmpty
            ? null
            : _facebookController.text.trim(),
        instagramUrl: _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
      );

      await _fs.upsertEntrepreneur(profile);
      _currentProfile = profile;

      if (!mounted) return;
      setState(() => _editMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berjaya disimpan.')),
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
      (_) => false,
    );
  }

  Future<void> _launchUrlString(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka pautan.')),
      );
    }
  }

  // OPEN GOOGLE MAPS FOR ADDRESS
  Future<void> _openMap(String address) async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _farmController.dispose();
    _shopController.dispose();
    _descController.dispose();
    _categoriesController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // THEME CONTROLLER (same pattern as LoginScreen)
    final themeController = ThemeControllerProvider.of(context);
    final isDark = themeController.mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Usahawan'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Tukar ke tema cerah' : 'Tukar ke tema gelap',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: themeController.toggle,
          ),
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
              : _buildProfileView(),
    );
  }

  // EDIT MODE
  Widget _buildEditForm() {
    final initialLetter = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';

    ImageProvider? avatarImage;
    if (_selectedImageFile != null) {
      avatarImage = FileImage(_selectedImageFile!);
    } else if (_currentProfile?.photoUrl != null &&
        _currentProfile!.photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_currentProfile!.photoUrl!);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Lengkapkan biodata untuk memudahkan pelanggan mengenali anda.',
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
                        color: Colors.white.withValues(alpha: 0.95),
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
              decoration: const InputDecoration(labelText: 'Nama penuh'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan nama' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'No. telefon'),
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
              controller: _farmController,
              decoration:
                  const InputDecoration(labelText: 'Lokasi ladang'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shopController,
              decoration:
                  const InputDecoration(labelText: 'Lokasi kedai'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoriesController,
              decoration: const InputDecoration(
                labelText:
                    'Kategori produk (cth: Buah segar, Jus, Kordial)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration:
                  const InputDecoration(labelText: 'Penerangan ringkas'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Media sosial (pilihan)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                labelText: 'Pautan WhatsApp (cth: https://wa.me/60...)',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _facebookController,
              decoration: const InputDecoration(
                labelText: 'Pautan Facebook',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instagramController,
              decoration: const InputDecoration(
                labelText: 'Pautan Instagram',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Simpan biodata'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // VIEW MODE
  Widget _buildProfileView() {
    final p = _currentProfile;
    if (p == null) {
      _editMode = true;
      return _buildEditForm();
    }

    ImageProvider? avatarImage;
    if (p.photoUrl != null && p.photoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(p.photoUrl!);
    }

    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';
    final hasAnySocial = (p.whatsappUrl?.isNotEmpty ?? false) ||
        (p.facebookUrl?.isNotEmpty ?? false) ||
        (p.instagramUrl?.isNotEmpty ?? false);

    return CustomScrollView(
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
                              _launchUrlString(p.whatsappUrl),
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
                              _launchUrlString(p.facebookUrl),
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
                              _launchUrlString(p.instagramUrl),
                          icon: const FaIcon(
                            FontAwesomeIcons.instagram,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _editMode = true);
                  },
                  child: const Text('Kemaskini profil'),
                ),
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
                    onTap: () => _openMap(p.farmLocation),
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
                    onTap: () => _openMap(p.shopLocation),
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
                          .map((c) => Chip(
                                label: Text(c),
                              ))
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
    );
  }
}
