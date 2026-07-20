import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/youtube_video.dart';

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Fetches video details from a YouTube URL or Video ID
  Future<YoutubeVideoMetadata> getVideoMetadata(String urlOrId) async {
    try {
      final videoId = VideoId.parseVideoId(urlOrId);
      if (videoId == null) {
        throw Exception("Invalid YouTube URL or ID");
      }

      final video = await _yt.videos.get(videoId);
      return YoutubeVideoMetadata(
        id: video.id.value,
        title: video.title,
        author: video.author,
        duration: video.duration ?? Duration.zero,
        thumbnailUrl: video.thumbnails.highResUrl,
        videoUrl: 'https://youtube.com/watch?v=${video.id.value}',
      );
    } catch (e) {
      throw Exception("Error fetching video metadata: $e");
    }
  }

  /// Gets the direct streaming audio URL for playback in SoLoud
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streams.getManifest(videoId);
      final audioOnlyStream = manifest.audioOnly.withHighestBitrate();
      if (audioOnlyStream == null) {
        throw Exception("No audio streams found for this video");
      }
      return audioOnlyStream.url.toString();
    } catch (e) {
      throw Exception("Error retrieving audio stream: $e");
    }
  }

  /// Gets direct streaming URLs for downloading (both audio and video streams)
  Future<StreamManifest> getStreamManifest(String videoId) async {
    try {
      return await _yt.videos.streams.getManifest(videoId);
    } catch (e) {
      throw Exception("Error fetching stream manifest: $e");
    }
  }

  void dispose() {
    _yt.close();
  }
}
