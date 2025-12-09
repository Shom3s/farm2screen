import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String type;

  /// Opsyenal – UID usahawan yang membuat hebahan.
  /// Biarkan kosong ('') untuk hebahan umum oleh admin.
  final String entrepreneurId;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.type,
    this.entrepreneurId = '',
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final rawDate = data['date'];
    final ts = rawDate is Timestamp ? rawDate : null;

    return Announcement(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      date: ts?.toDate() ?? DateTime.now(),
      type: data['type'] ?? '',
      entrepreneurId: data['entrepreneurId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'date': date,
        'type': type,
        'entrepreneurId': entrepreneurId,
      };
}
