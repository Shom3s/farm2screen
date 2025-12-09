import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/announcement.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _fs = FirestoreService();
  final _authService = AuthService();

  String _filterType = 'Semua';
  bool _canPost = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final role = await _authService.getUserRole(user.uid);
    setState(() {
      _canPost = role == UserRole.entrepreneur;
    });
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _typeColor(String type, BuildContext context) {
    final t = type.toLowerCase();
    final scheme = Theme.of(context).colorScheme;

    if (t.contains('promo')) return scheme.secondaryContainer;
    if (t.contains('tip') || t.contains('teknik')) {
      return scheme.tertiaryContainer;
    }
    if (t.contains('pasar') || t.contains('harga')) {
      return scheme.primaryContainer;
    }
    return scheme.surfaceVariant;
  }

  Future<void> _openNewAnnouncementSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String type = 'Umum';

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Text(
                  'Hebahan baharu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tajuk hebahan',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Masukkan tajuk' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Umum',
                      child: Text('Umum'),
                    ),
                    DropdownMenuItem(
                      value: 'Promosi',
                      child: Text('Promosi'),
                    ),
                    DropdownMenuItem(
                      value: 'Tip / Teknik',
                      child: Text('Tip / Teknik'),
                    ),
                    DropdownMenuItem(
                      value: 'Harga Pasaran',
                      child: Text('Harga Pasaran'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) type = v;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Kandungan hebahan',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Masukkan kandungan'
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final user = FirebaseAuth.instance.currentUser;
                      final announcement = Announcement(
                        id: '',
                        title: titleController.text.trim(),
                        content: contentController.text.trim(),
                        date: DateTime.now(),
                        type: type,
                        entrepreneurId: user?.uid ?? '',
                      );

                      try {
                        await _fs.addAnnouncement(announcement);
                        if (context.mounted) Navigator.of(context).pop();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal menyimpan hebahan: $e'),
                          ),
                        );
                      }
                    },
                    child: const Text('Terbitkan hebahan'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hebahan & Ilmu Teknikal'),
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: _fs.announcementsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child:
                  Text('Ralat memuatkan hebahan: ${snapshot.error}'),
            );
          }

          final anns = snapshot.data ?? [];
          if (anns.isEmpty) {
            return const Center(
              child: Text('Tiada hebahan lagi.'),
            );
          }

          final types = <String>{'Semua'};
          for (final a in anns) {
            if (a.type.isNotEmpty) types.add(a.type);
          }

          final filtered = _filterType == 'Semua'
              ? anns
              : anns.where((a) => a.type == _filterType).toList();

          return Column(
            children: [
              // Type filter chips
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: types.map((t) {
                    final selected = t == _filterType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _filterType = t);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final a = filtered[index];

                    return Card(
                      elevation: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: _typeColor(a.type, context),
                              width: 6,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(a.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (a.type.isNotEmpty)
                                    Chip(
                                      label: Text(
                                        a.type,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor:
                                          _typeColor(a.type, context),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(a.content),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton:
          _canPost ? FloatingActionButton(
            onPressed: _openNewAnnouncementSheet,
            child: const Icon(Icons.add),
          ) : null,
    );
  }
}
