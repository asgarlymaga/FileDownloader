import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_video.dart';

class FFmpegService {
  final YoutubeExplode _yt = YoutubeExplode();

  // Streams to report progress back to the UI
  final StreamController<double> _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  /// Downloads raw streams, processes the audio using the asetrate & atempo filter
  /// to bake a specified frequency (e.g. 432 Hz) into an MP3 file.
  Future<DownloadItem> convertAndSaveTo432HzMp3({
    required YoutubeVideoMetadata metadata,
    required double targetHz,
  }) async {
    _progressController.add(0.05);

    try {
      final manifest = await _yt.videos.streams.getManifest(metadata.id);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      if (audioStreamInfo == null) {
        throw Exception("No suitable audio stream found.");
      }

      final appDir = await getApplicationDocumentsDirectory();

      // Clean up title for file safety
      final safeTitle = metadata.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      final tempAudioFile = File('${appDir.path}/temp_${metadata.id}_raw.webm');
      final outputMp3File = File('${appDir.path}/${safeTitle}_${targetHz.toInt()}Hz.mp3');

      // 1. Download raw audio stream
      _progressController.add(0.1);
      final stream = _yt.videos.streams.get(audioStreamInfo);
      final outputStream = tempAudioFile.openWrite();

      double totalBytes = audioStreamInfo.size.totalBytes.toDouble();
      double downloadedBytes = 0.0;

      await for (final data in stream) {
        outputStream.add(data);
        downloadedBytes += data.length;
        // Map download progress to 0.1 - 0.5
        double progress = 0.1 + (downloadedBytes / totalBytes) * 0.4;
        _progressController.add(progress);
      }
      await outputStream.flush();
      await outputStream.close();

      _progressController.add(0.5);

      // Delete existing output if any
      if (await outputMp3File.exists()) {
        await outputMp3File.delete();
      }

      // 2. Process with FFmpeg
      // Calculate speed ratio: targetHz / 440.0
      double ratio = targetHz / 440.0;
      double sampleRate = 44100.0 * ratio;
      double tempo = 1.0 / ratio;

      // Ensure formatting and force standard resampling base to guarantee accurate pitch shifts
      String asetrateFilter = "aresample=44100,asetrate=${sampleRate.toStringAsFixed(2)}";
      String atempoFilter = "atempo=${tempo.toStringAsFixed(4)}";

      // Escape quotes in metadata strings to prevent breaking FFmpeg commands
      final escapedTitle = metadata.title.replaceAll('"', '\\"');
      final escapedArtist = metadata.author.replaceAll('"', '\\"');

      // Build FFmpeg command to shift pitch while restoring original speed/tempo
      // Uses LGPL-friendly filters
      final command = '-y -i "${tempAudioFile.path}" -af "$asetrateFilter,$atempoFilter" -metadata title="$escapedTitle" -metadata artist="$escapedArtist" "${outputMp3File.path}"';

      _progressController.add(0.6);

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up raw temp webm file
      if (await tempAudioFile.exists()) {
        await tempAudioFile.delete();
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _progressController.add(1.0);
        return DownloadItem(
          id: metadata.id,
          title: metadata.title,
          author: metadata.author,
          filePath: outputMp3File.path,
          type: DownloadType.audio,
          frequencyHz: targetHz,
          duration: metadata.duration,
        );
      } else {
        final logs = await session.getLogs();
        final failStackTrace = logs.map((l) => l.getMessage()).join("\n");
        throw Exception("FFmpeg processing failed: $failStackTrace");
      }
    } catch (e) {
      _progressController.add(0.0);
      debugPrint("Conversion/Download Error: $e");
      rethrow;
    }
  }

  /// Downloads raw stream, merges audio and video, and saves as an MP4.
  Future<DownloadItem> downloadVideoMp4({
    required YoutubeVideoMetadata metadata,
  }) async {
    _progressController.add(0.05);

    try {
      final manifest = await _yt.videos.streams.getManifest(metadata.id);
      final videoStreamInfo = manifest.muxed.withHighestBitrate();
      if (videoStreamInfo == null) {
        throw Exception("No suitable MP4 stream found.");
      }

      final appDir = await getApplicationDocumentsDirectory();
      final safeTitle = metadata.title.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      final outputMp4File = File('${appDir.path}/${safeTitle}.mp4');

      if (await outputMp4File.exists()) {
        await outputMp4File.delete();
      }

      _progressController.add(0.1);
      final stream = _yt.videos.streams.get(videoStreamInfo);
      final outputStream = outputMp4File.openWrite();

      double totalBytes = videoStreamInfo.size.totalBytes.toDouble();
      double downloadedBytes = 0.0;

      await for (final data in stream) {
        outputStream.add(data);
        downloadedBytes += data.length;
        double progress = 0.1 + (downloadedBytes / totalBytes) * 0.85;
        _progressController.add(progress);
      }
      await outputStream.flush();
      await outputStream.close();

      _progressController.add(1.0);

      return DownloadItem(
        id: metadata.id,
        title: metadata.title,
        author: metadata.author,
        filePath: outputMp4File.path,
        type: DownloadType.video,
        frequencyHz: 440.0, // Stored as standard speed/tuning
        duration: metadata.duration,
      );
    } catch (e) {
      _progressController.add(0.0);
      debugPrint("Video Download Error: $e");
      rethrow;
    }
  }

  void dispose() {
    _yt.close();
  }
}
