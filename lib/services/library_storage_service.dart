import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/youtube_video.dart';

class LibraryStorageService {
  static const String _filename = 'library_db.json';

  Future<File> _getDatabaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_filename');
  }

  Future<List<DownloadItem>> loadLibrary() async {
    try {
      final file = await _getDatabaseFile();
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(contents);

      // Let's also verify files actually exist on disk before showing them in the library!
      final List<DownloadItem> existingItems = [];
      for (final json in decoded) {
        final item = DownloadItem.fromJson(json);
        if (await File(item.filePath).exists()) {
          existingItems.add(item);
        }
      }
      return existingItems;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLibrary(List<DownloadItem> library) async {
    try {
      final file = await _getDatabaseFile();
      final listJson = library.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(listJson));
    } catch (_) {}
  }
}
