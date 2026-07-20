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

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(SearchState.initial());

  Future<void> searchVideo(String urlOrId) async {
    if (urlOrId.trim().isEmpty) return;
    state = SearchState.loading();
    try {
      final service = _ref.read(youtubeServiceProvider);
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

final searchStateProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
