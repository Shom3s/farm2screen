import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final _client = Supabase.instance.client;
  static const String _bucket = 'profile-pictures';

  Future<String> uploadProfileImage(File file, String userId) async {
    final bytes = await file.readAsBytes();
    final path = '$userId.jpg';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);
    return publicUrl;
  }
}
