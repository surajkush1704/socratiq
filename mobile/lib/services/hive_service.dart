import 'package:hive_flutter/hive_flutter.dart';

import '../models/content_model.dart';

class HiveService {
  static const String contentBox = 'content_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(contentBox);
  }

  static Future<void> saveContent(ContentModel content) async {
    final box = Hive.box(contentBox);
    await box.put(content.documentName, content.toMap());
  }

  static List<ContentModel> getAllContent() {
    final box = Hive.box(contentBox);
    return box.keys.map((key) {
      return ContentModel.fromMap(Map<String, dynamic>.from(box.get(key)));
    }).toList();
  }

  static ContentModel? getContent(String documentName) {
    final box = Hive.box(contentBox);
    final data = box.get(documentName);
    if (data == null) return null;
    return ContentModel.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<void> deleteContent(String documentName) async {
    final box = Hive.box(contentBox);
    await box.delete(documentName);
  }
}
