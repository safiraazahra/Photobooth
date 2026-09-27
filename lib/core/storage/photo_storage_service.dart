import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

class PhotoStorageService {
  static const String boxName = 'photo_results';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<Uint8List>(
        boxName,
      );
    }
  }

  static Box<Uint8List> get _box {
    return Hive.box<Uint8List>(
      boxName,
    );
  }

  static Future<String> savePhoto(
    Uint8List bytes,
  ) async {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();

    await _box.put(
      id,
      bytes,
    );

    return id;
  }

  static Uint8List? getPhoto(
    String id,
  ) {
    return _box.get(id);
  }

  static List<Uint8List> getAllPhotos() {
    return _box.values.toList();
  }

  static int get count {
    return _box.length;
  }

  static Future<void> deletePhoto(
    String id,
  ) async {
    await _box.delete(id);
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }
}
