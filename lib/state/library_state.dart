import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_video.dart';
import '../state/providers.dart';

class LibraryNotifier extends StateNotifier<List<DownloadItem>> {
  final Ref _ref;

  LibraryNotifier(this._ref) : super([]) {
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final storage = _ref.read(libraryStorageServiceProvider);
    final items = await storage.loadLibrary();
    state = items;
  }

  Future<void> addDownloadedItem(DownloadItem item) async {
    final storage = _ref.read(libraryStorageServiceProvider);
    final updatedList = [...state, item];
    state = updatedList;
    await storage.saveLibrary(updatedList);
  }

  Future<void> deleteItem(DownloadItem item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    final storage = _ref.read(libraryStorageServiceProvider);
    final updatedList = state.where((element) => element.filePath != item.filePath).toList();
    state = updatedList;
    await storage.saveLibrary(updatedList);
  }
}

final libraryStateProvider = StateNotifierProvider<LibraryNotifier, List<DownloadItem>>((ref) {
  return LibraryNotifier(ref);
});
