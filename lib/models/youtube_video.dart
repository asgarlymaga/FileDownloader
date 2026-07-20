class YoutubeVideoMetadata {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final String videoUrl;

  const YoutubeVideoMetadata({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'duration': duration.inMilliseconds,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
    };
  }

  factory YoutubeVideoMetadata.fromJson(Map<String, dynamic> json) {
    return YoutubeVideoMetadata(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      thumbnailUrl: json['thumbnailUrl'] as String,
      videoUrl: json['videoUrl'] as String,
    );
  }
}

enum DownloadType { audio, video }

class DownloadItem {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final DownloadType type;
  final double frequencyHz; // Pitch used during bake (e.g. 432)
  final Duration duration;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.type,
    required this.frequencyHz,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'type': type.name,
      'frequencyHz': frequencyHz,
      'duration': duration.inMilliseconds,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      filePath: json['filePath'] as String,
      type: DownloadType.values.byName(json['type'] as String),
      frequencyHz: (json['frequencyHz'] as num).toDouble(),
      duration: Duration(milliseconds: json['duration'] as int),
    );
  }
}
