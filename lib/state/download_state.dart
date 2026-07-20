import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_video.dart';
import '../state/providers.dart';
import '../state/library_state.dart';

class DownloadProgress {
  final bool isDownloading;
  final double progress; // 0.0 to 1.0
  final String statusText;
  final String? error;

  DownloadProgress({
    required this.isDownloading,
    required this.progress,
    required this.statusText,
    this.error,
  });

  factory DownloadProgress.initial() => DownloadProgress(
        isDownloading: false,
        progress: 0.0,
        statusText: '',
      );

  factory DownloadProgress.downloading(double progress, String statusText) => DownloadProgress(
        isDownloading: true,
        progress: progress,
        statusText: statusText,
      );

  factory DownloadProgress.success() => DownloadProgress(
        isDownloading: false,
        progress: 1.0,
        statusText: 'Download Complete!',
      );

  factory DownloadProgress.failed(String error) => DownloadProgress(
        isDownloading: false,
        progress: 0.0,
        statusText: 'Download Failed',
        error: error,
      );
}

class DownloadNotifier extends Notifier<DownloadProgress> {
  @override
  DownloadProgress build() {
    return DownloadProgress.initial();
  }

  Future<void> startAudioConversionAndDownload({
    required YoutubeVideoMetadata metadata,
    required double targetHz,
  }) async {
    state = DownloadProgress.downloading(0.05, "Initializing audio extraction...");

    final ffmpegService = ref.read(ffmpegServiceProvider);

    // Wire progress updates to our state
    final subscription = ffmpegService.progressStream.listen((progress) {
      String status = "Extracting raw stream...";
      if (progress > 0.5) {
        status = "Baking $targetHz Hz pitch filter using FFmpeg...";
      }
      if (progress >= 1.0) {
        status = "Metadata tagged and saved!";
      }
      state = DownloadProgress.downloading(progress, status);
    });

    try {
      final downloadedItem = await ffmpegService.convertAndSaveTo432HzMp3(
        metadata: metadata,
        targetHz: targetHz,
      );

      // Add downloaded item to global library state
      await ref.read(libraryStateProvider.notifier).addDownloadedItem(downloadedItem);
      state = DownloadProgress.success();
    } catch (e) {
      state = DownloadProgress.failed(e.toString().replaceAll("Exception: ", ""));
    } finally {
      subscription.cancel();
    }
  }

  Future<void> startVideoDownload({
    required YoutubeVideoMetadata metadata,
  }) async {
    state = DownloadProgress.downloading(0.05, "Initializing video download...");

    final ffmpegService = ref.read(ffmpegServiceProvider);
    final subscription = ffmpegService.progressStream.listen((progress) {
      state = DownloadProgress.downloading(progress, "Downloading high quality muxed MP4...");
    });

    try {
      final downloadedItem = await ffmpegService.downloadVideoMp4(metadata: metadata);

      // Add downloaded item to global library state
      await ref.read(libraryStateProvider.notifier).addDownloadedItem(downloadedItem);
      state = DownloadProgress.success();
    } catch (e) {
      state = DownloadProgress.failed(e.toString().replaceAll("Exception: ", ""));
    } finally {
      subscription.cancel();
    }
  }

  void reset() {
    state = DownloadProgress.initial();
  }
}

final downloadStateProvider = NotifierProvider<DownloadNotifier, DownloadProgress>(DownloadNotifier.new);
