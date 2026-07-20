import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/youtube_service.dart';
import '../services/audio_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/library_storage_service.dart';

// Service providers
final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  final service = FFmpegService();
  ref.onDispose(() => service.dispose());
  return service;
});

final libraryStorageServiceProvider = Provider<LibraryStorageService>((ref) {
  return LibraryStorageService();
});
