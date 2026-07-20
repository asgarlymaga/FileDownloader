import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/youtube_video.dart';
import '../state/providers.dart';

class SearchState {
  final bool isLoading;
  final YoutubeVideoMetadata? metadata;
  final String? errorMessage;

  SearchState({
    required this.isLoading,
    this.metadata,
    this.errorMessage,
  });

  factory SearchState.initial() => SearchState(isLoading: false);
  factory SearchState.loading() => SearchState(isLoading: true);
  factory SearchState.success(YoutubeVideoMetadata metadata) => SearchState(isLoading: false, metadata: metadata);
  factory SearchState.error(String message) => SearchState(isLoading: false, errorMessage: message);
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    return SearchState.initial();
  }

  Future<void> searchVideo(String urlOrId) async {
    if (urlOrId.trim().isEmpty) return;
    state = SearchState.loading();
    try {
      final service = ref.read(youtubeServiceProvider);
      final metadata = await service.getVideoMetadata(urlOrId);
      state = SearchState.success(metadata);
    } catch (e) {
      state = SearchState.error(e.toString().replaceAll("Exception: ", ""));
    }
  }

  void clearSearch() {
    state = SearchState.initial();
  }
}

final searchStateProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
