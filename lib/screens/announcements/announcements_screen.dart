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
    // default “general” purple-ish tone
    return const Color(0xFFB388F2);
  }

  Future<void> _openNewAnnouncementSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String type = 'Umum';
    DateTime? selectedExpiry;

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
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Form(
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

                    // Tajuk
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tajuk hebahan',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Masukkan tajuk' : null,
                    ),
                    const SizedBox(height: 12),

                    // Kategori
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

                    // Tarikh tamat (expiry) – date picker
                    GestureDetector(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              selectedExpiry ?? now.add(const Duration(days: 7)),
                          firstDate: now,
                          lastDate: DateTime(now.year + 3),
                        );

                        if (picked != null) {
                          setModalState(() {
                            selectedExpiry = picked;
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Tarikh tamat',
                            hintText: selectedExpiry == null
                                ? 'Pilih tarikh tamat'
                                : '${selectedExpiry!.day.toString().padLeft(2, '0')}/'
                                  '${selectedExpiry!.month.toString().padLeft(2, '0')}/'
                                  '${selectedExpiry!.year}',
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (_) => selectedExpiry == null
                              ? 'Sila pilih tarikh tamat'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kandungan
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
                          final now = DateTime.now();

                          final announcement = Announcement(
                            id: '',
                            title: titleController.text.trim(),
                            content: contentController.text.trim(),
                            date: now,
                            type: type,
                            entrepreneurId: user?.uid ?? '',
                            // requires expiresAt in your model
                            expiresAt: selectedExpiry,
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
              );
            },
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
              child: Text('Ralat memuatkan hebahan: ${snapshot.error}'),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final a = filtered[index];
                    final color = _typeColor(a.type, context);

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _AnnouncementCard(
                        announcement: a,
                        accentColor: color,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton(
              onPressed: _openNewAnnouncementSheet,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// =======================
/// Announcement card UI
/// =======================

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final Color accentColor;

  const _AnnouncementCard({
    required this.announcement,
    required this.accentColor,
  });

  String _formatPretty(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[d.month - 1];
    final day = d.day.toString().padLeft(2, '0');
    return '$m $day, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final created = _formatPretty(announcement.date);
    // Use saved expiry date if available, otherwise +9 days
    final expiryDate = announcement.expiresAt ??
        announcement.date.add(const Duration(days: 9));
    final expires = _formatPretty(expiryDate);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          // Left coloured strip
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: Color(0xFF8A4FFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        announcement.type.isEmpty
                            ? 'General'
                            : announcement.type,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8A4FFF),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Title
                Text(
                  announcement.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),

                const SizedBox(height: 4),

                // Content
                Text(
                  announcement.content,
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 10),

                // Bottom row: created and expires
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      created,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.schedule,
                      size: 15,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: $expires',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
