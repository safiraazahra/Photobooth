import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoUploadService {
  static const String bucketName = 'photobooth';

  static Future<String> uploadPhoto({
    required String photoId,
    required Uint8List bytes,
  }) async {
    final SupabaseClient supabase = Supabase.instance.client;

    final storage = supabase.storage.from(bucketName);

    final String filePath = '$photoId.jpg';

    await storage.uploadBinary(
      filePath,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    final String publicUrl = storage.getPublicUrl(filePath);

    final String downloadUrl = '$publicUrl?download=$filePath';

    return downloadUrl;
  }

  static Future<void> deletePhoto(
    String photoId,
  ) async {
    try {
      await Supabase.instance.client.storage.from(bucketName).remove([
        '$photoId.jpg',
      ]);
    } catch (_) {
    }
  }
}
