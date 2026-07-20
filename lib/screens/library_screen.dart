import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/youtube_video.dart';
import '../state/providers.dart';
import '../state/library_state.dart';
import '../services/audio_service.dart';
import '../widgets/visualizer_widget.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  DownloadItem? _playingAudioItem;
  double _frequencyHz = 432.0;

  @override
  void deactivate() {
    // Stop local audio before leaving/switching tabs to avoid leaking audio
    ref.read(audioServiceProvider).stop();
    super.deactivate();
  }

  /// Play offline audio using SoLoud
  Future<void> _playLocalAudio(DownloadItem item) async {
    final audioService = ref.read(audioServiceProvider);
    setState(() {
      _playingAudioItem = item;
      _frequencyHz = item.frequencyHz;
    });

    try {
      audioService.setTargetFrequency(_frequencyHz);
      await audioService.play(item.filePath, isLocal: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback Error: $e')),
        );
      }
    }
  }

  /// Toggle pause/resume
  Future<void> _togglePlayPause() async {
    final audioService = ref.read(audioServiceProvider);
    if (audioService.isPlaying) {
      await audioService.pause();
    } else {
      await audioService.resume();
    }
    setState(() {});
  }

  /// Stop audio playback
  Future<void> _stopAudio() async {
    await ref.read(audioServiceProvider).stop();
    setState(() {
      _playingAudioItem = null;
    });
  }

  /// Render bottom sheet / bottom panel when a local MP3 is playing
  Widget _buildBottomPlayerPanel(AudioService audioService) {
    if (_playingAudioItem == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.blue, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _playingAudioItem!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Offline MP3 • Baked at ${_playingAudioItem!.frequencyHz.toInt()}Hz',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _stopAudio,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live FFT visualizer for downloaded file!
            VisualizerWidget(
              visualizerStream: audioService.visualizerStream,
              isPlaying: audioService.isPlaying,
            ),
            const SizedBox(height: 8),

            // Controls & Position Slider
            StreamBuilder<double>(
              stream: audioService.positionStream,
              initialData: 0.0,
              builder: (context, snapshot) {
                final double currentPos = snapshot.data ?? 0.0;
                final double totalDurationSec = _playingAudioItem!.duration.inSeconds.toDouble();
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(clampedPos / 60).floor()}:${(clampedPos % 60).floor().toString().padLeft(2, "0")}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          // Mini Play-pause button in slider row
                          StreamBuilder<bool>(
                            stream: audioService.isPlayingStream,
                            initialData: audioService.isPlaying,
                            builder: (context, playStateSnapshot) {
                              final isPlaying = playStateSnapshot.data ?? false;
                              return InkWell(
                                onTap: _togglePlayPause,
                                child: CircleAvatar(
                                  radius: 18,
                                  child: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    size: 18,
                                  ),
                                ),
                              );
                            },
                          ),
                          Text(
                            '${(totalDurationSec / 60).floor()}:${(totalDurationSec % 60).floor().toString().padLeft(2, "0")}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
            const Divider(),

            // Real-time Slider allows manipulating the local audio speed & frequency in real time!
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tweak Live Pitch:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${_frequencyHz.toStringAsFixed(1)} Hz',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            Slider(
              min: 400.0,
              max: 600.0,
              divisions: 200,
              value: _frequencyHz,
              onChanged: (val) {
                setState(() {
                  _frequencyHz = val;
                });
                audioService.setTargetFrequency(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Play offline video in a full screen dialog using video_player
  void _playLocalVideo(DownloadItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return VideoPlayerDialog(filePath: item.filePath, title: item.title);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryStateProvider);
    final audioService = ref.watch(audioServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads Library'),
        centerTitle: true,
      ),
      bottomNavigationBar: _buildBottomPlayerPanel(audioService),
      body: library.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_for_offline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No local files found',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Downloads will appear here automatically.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: library.length,
              itemBuilder: (context, index) {
                final item = library[index];
                final isAudio = item.type == DownloadType.audio;
                final isCurrentlyPlayingThis = _playingAudioItem?.filePath == item.filePath;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isAudio ? Colors.blue.shade50 : Colors.teal.shade50,
                      child: Icon(
                        isAudio ? Icons.audiotrack : Icons.movie,
                        color: isAudio ? Colors.blue : Colors.teal,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          item.author,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAudio ? Colors.blue.withOpacity(0.15) : Colors.teal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isAudio ? 'MP3 • ${item.frequencyHz.toInt()}Hz' : 'MP4',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isAudio ? Colors.blue.shade900 : Colors.teal.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: ${item.duration.inMinutes}:${(item.duration.inSeconds % 60).toString().padLeft(2, "0")}',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Play action button
                        IconButton(
                          icon: Icon(
                            isCurrentlyPlayingThis
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: isAudio ? Colors.blue : Colors.teal,
                            size: 32,
                          ),
                          onPressed: () {
                            if (isAudio) {
                              if (isCurrentlyPlayingThis) {
                                _togglePlayPause();
                              } else {
                                _playLocalAudio(item);
                              }
                            } else {
                              _playLocalVideo(item);
                            }
                          },
                        ),
                        // Delete action button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            // Quick confirm dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete File'),
                                content: Text('Are you sure you want to delete "${item.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (isCurrentlyPlayingThis) {
                                        _stopAudio();
                                      }
                                      ref.read(libraryStateProvider.notifier).deleteItem(item);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Offline Video player dialog
class VideoPlayerDialog extends StatefulWidget {
  final String filePath;
  final String title;

  const VideoPlayerDialog({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }).catchError((error) {
        setState(() {
          _errorMessage = error.toString();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error loading video: $_errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (!_initialized)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: CircularProgressIndicator(),
            )
          else ...[
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.teal,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
