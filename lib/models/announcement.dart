import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;          // tarikh hebahan dibuat
  final String type;
  final String entrepreneurId;

  /// Opsyenal – tarikh luput hebahan (untuk paparan "Expires")
  final DateTime? expiresAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.type,
    this.entrepreneurId = '',
    this.expiresAt,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final rawDate = data['date'];
    final ts = rawDate is Timestamp ? rawDate : null;

    final rawExpire = data['expiresAt'];
    final expireTs = rawExpire is Timestamp ? rawExpire : null;

    final created = ts?.toDate() ?? DateTime.now();
    // Untuk dokumen lama tanpa expiresAt, anggap 7 hari selepas tarikh hebahan
    final expires =
        expireTs?.toDate() ?? created.add(const Duration(days: 7));

    return Announcement(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      date: created,
      type: data['type'] ?? '',
      entrepreneurId: data['entrepreneurId'] ?? '',
      expiresAt: expires,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'date': date,
        'type': type,
        'entrepreneurId': entrepreneurId,
        'expiresAt': expiresAt,
      };
}
