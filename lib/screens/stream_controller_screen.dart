import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../state/search_state.dart';
import '../state/download_state.dart';
import '../widgets/visualizer_widget.dart';

class StreamControllerScreen extends ConsumerStatefulWidget {
  const StreamControllerScreen({super.key});

  @override
  ConsumerState<StreamControllerScreen> createState() => _StreamControllerScreenState();
}

class _StreamControllerScreenState extends ConsumerState<StreamControllerScreen> {
  final TextEditingController _urlController = TextEditingController();
  double _frequencyHz = 432.0;
  bool _isStreaming = false;
  bool _isBuffering = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Preset Frequency button generator
  Widget _buildPresetButton(double hz, String label) {
    final isSelected = _frequencyHz == hz;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey.shade200,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _frequencyHz = hz;
          });
          ref.read(audioServiceProvider).setTargetFrequency(hz);
        }
      },
    );
  }

  Future<void> _startStreaming(String videoId) async {
    setState(() {
      _isBuffering = true;
      _isStreaming = false;
    });

    final audioService = ref.read(audioServiceProvider);
    final youtubeService = ref.read(youtubeServiceProvider);

    try {
      // 1. Get audio stream URL
      final audioUrl = await youtubeService.getAudioStreamUrl(videoId);

      // 2. Play using SoLoud
      audioService.setTargetFrequency(_frequencyHz);
      await audioService.play(audioUrl, isLocal: false);

      setState(() {
        _isStreaming = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Streaming error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final audioService = ref.read(audioServiceProvider);
    if (audioService.isPlaying) {
      await audioService.pause();
    } else {
      if (audioService.currentUrlOrPath != null) {
        await audioService.resume();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final downloadState = ref.watch(downloadStateProvider);
    final audioService = ref.watch(audioServiceProvider);

    // List of samples for quick user testing
    final sampleUrls = [
      {
        'title': '432 Hz Tuning Fork',
        'url': 'https://www.youtube.com/watch?v=F0f8gE4vG6c'
      },
      {
        'title': 'Solfeggio 528 Hz',
        'url': 'https://www.youtube.com/watch?v=1bV98L_W3sU'
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pitch Shifter & Streamer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input box
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YouTube Video Input',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                hintText: 'Paste YouTube URL or ID here',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: searchState.isLoading
                                ? null
                                : () {
                                    ref
                                        .read(searchStateProvider.notifier)
                                        .searchVideo(_urlController.text);
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                            child: searchState.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Quick sample chips
                      Wrap(
                        spacing: 8,
                        children: sampleUrls.map((sample) {
                          return ActionChip(
                            avatar: const Icon(Icons.play_circle_outline, size: 16),
                            label: Text(sample['title']!),
                            onPressed: () {
                              _urlController.text = sample['url']!;
                              ref
                                  .read(searchStateProvider.notifier)
                                  .searchVideo(sample['url']!);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Error banner if any
              if (searchState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          searchState.errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loaded Video UI
              if (searchState.metadata != null) ...[
                // Video details card
                Card(
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Video thumbnail
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Image.network(
                            searchState.metadata!.thumbnailUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 180,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image, size: 48),
                            ),
                          ),
                          Container(
                            color: Colors.black.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.all(8),
                            child: Text(
                              '${searchState.metadata!.duration.inMinutes}:${(searchState.metadata!.duration.inSeconds % 60).toString().padLeft(2, "0")}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              searchState.metadata!.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              searchState.metadata!.author,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Real-time Visualizer
                            VisualizerWidget(
                              visualizerStream: audioService.visualizerStream,
                              isPlaying: audioService.isPlaying && _isStreaming,
                            ),
                            const SizedBox(height: 16),

                            // Streaming controllers
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (_isBuffering)
                                  const CircularProgressIndicator()
                                else if (!_isStreaming)
                                  ElevatedButton.icon(
                                    onPressed: () => _startStreaming(searchState.metadata!.id),
                                    icon: const Icon(Icons.cast_connected),
                                    label: const Text('Stream Real-time 432Hz'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                  )
                                else ...[
                                  // Play/Pause stream
                                  StreamBuilder<bool>(
                                    stream: audioService.isPlayingStream,
                                    initialData: audioService.isPlaying,
                                    builder: (context, snapshot) {
                                      final isPlaying = snapshot.data ?? false;
                                      return FloatingActionButton(
                                        mini: true,
                                        onPressed: _togglePlayPause,
                                        child: Icon(
                                          isPlaying ? Icons.pause : Icons.play_arrow,
                                        ),
                                      );
                                    },
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await audioService.stop();
                                      setState(() {
                                        _isStreaming = false;
                                      });
                                    },
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Stop'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ]
                              ],
                            ),

                            // Position Slider
                            if (_isStreaming) ...[
                              const SizedBox(height: 8),
                              StreamBuilder<double>(
                                stream: audioService.positionStream,
                                initialData: 0.0,
                                builder: (context, snapshot) {
                                  final double currentPos = snapshot.data ?? 0.0;
                                  final double totalDurationSec = searchState.metadata!.duration.inSeconds.toDouble();
                                  final double clampedPos = currentPos.clamp(0.0, totalDurationSec);

                                  return Column(
                                    children: [
                                      Slider(
                                        min: 0.0,
                                        max: totalDurationSec > 0 ? totalDurationSec : 1.0,
                                        value: clampedPos,
                                        onChanged: (val) {
                                          audioService.seek(val);
                                        },
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(clampedPos / 60).floor()}:${(clampedPos % 60).floor().toString().padLeft(2, "0")}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            '${(totalDurationSec / 60).floor()}:${(totalDurationSec % 60).floor().toString().padLeft(2, "0")}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      )
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pitch Controls card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pitch Tuning / Hz',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_frequencyHz.toStringAsFixed(1)} Hz',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          min: 400.0,
                          max: 600.0,
                          divisions: 200,
                          label: '${_frequencyHz.toStringAsFixed(1)} Hz',
                          value: _frequencyHz,
                          onChanged: (val) {
                            setState(() {
                              _frequencyHz = val;
                            });
                            ref.read(audioServiceProvider).setTargetFrequency(val);
                          },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildPresetButton(440.0, '440 Hz (Standard)'),
                            _buildPresetButton(432.0, '432 Hz (Universal)'),
                            _buildPresetButton(528.0, '528 Hz (Solfeggio)'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Downloads card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Download Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (downloadState.isDownloading) ...[
                          LinearProgressIndicator(value: downloadState.progress),
                          const SizedBox(height: 8),
                          Text(
                            downloadState.statusText,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          if (downloadState.progress > 0)
                            Text(
                              'Progress: ${(downloadState.progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(downloadStateProvider.notifier)
                                        .startAudioConversionAndDownload(
                                          metadata: searchState.metadata!,
                                          targetHz: _frequencyHz,
                                        );
                                  },
                                  icon: const Icon(Icons.music_note),
                                  label: Text('Bake ${_frequencyHz.toInt()}Hz MP3'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(downloadStateProvider.notifier)
                                        .startVideoDownload(metadata: searchState.metadata!);
                                  },
                                  icon: const Icon(Icons.video_library),
                                  label: const Text('Download MP4'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (downloadState.error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Error: ${downloadState.error}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
