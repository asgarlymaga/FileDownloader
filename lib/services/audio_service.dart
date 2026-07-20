import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  bool _initialized = false;
  AudioSource? _activeSource;
  SoundHandle? _activeHandle;

  double _targetHz = 432.0;
  bool _isPlaying = false;
  String? _currentUrlOrPath;
  File? _tempStreamingFile;

  // Stream controller to broadcast visualization FFT/Waveform data if needed, or simply playback status
  final StreamController<double> _playbackPositionController = StreamController<double>.broadcast();
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  final StreamController<List<double>> _visualizerController = StreamController<List<double>>.broadcast();

  Timer? _positionTimer;
  Timer? _visualizerTimer;

  bool get isInitialized => _initialized;
  double get targetHz => _targetHz;
  bool get isPlaying => _isPlaying;
  String? get currentUrlOrPath => _currentUrlOrPath;

  Stream<double> get positionStream => _playbackPositionController.stream;
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  Stream<List<double>> get visualizerStream => _visualizerController.stream;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await SoLoud.instance.init();
      _initialized = true;
    } catch (e) {
      debugPrint("Error initializing SoLoud: $e");
    }
  }

  /// Calculates speed factor needed to scale 440 Hz standard to the target Hz
  double get pitchMultiplier => _targetHz / 440.0;

  /// Update the pitch/frequency multiplier in real-time
  void setTargetFrequency(double hz) {
    _targetHz = hz;
    if (_initialized && _activeHandle != null) {
      try {
        SoLoud.instance.setRelativePlaySpeed(_activeHandle!, pitchMultiplier);
      } catch (e) {
        debugPrint("Error shifting pitch: $e");
      }
    }
  }

  /// Helper to buffer a remote streaming URL into a temporary local file
  Future<File> _bufferRemoteUrlToTempFile(String url) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/soloud_stream_temp.mp3');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception("Failed to stream remote audio. Server returned: ${response.statusCode}");
    }

    final iosSink = tempFile.openWrite();
    await response.pipe(iosSink);
    return tempFile;
  }

  /// Play an audio URL (YouTube live audio stream) or a local file path
  Future<void> play(String urlOrPath, {bool isLocal = false}) async {
    await init();
    await stop();

    try {
      _currentUrlOrPath = urlOrPath;
      String filePathToLoad = urlOrPath;

      if (!isLocal) {
        // If it's a remote stream URL, buffer it into a local temp file first
        _tempStreamingFile = await _bufferRemoteUrlToTempFile(urlOrPath);
        filePathToLoad = _tempStreamingFile!.path;
      }

      // Load using the local file path
      _activeSource = await SoLoud.instance.loadFile(filePathToLoad);

      if (_activeSource == null) {
        throw Exception("Could not load audio source: $filePathToLoad");
      }

      _activeHandle = await SoLoud.instance.play(_activeSource!);

      // Apply the pitch scale factors immediately
      SoLoud.instance.setRelativePlaySpeed(_activeHandle!, pitchMultiplier);

      _isPlaying = true;
      _isPlayingController.add(true);
      _startPositionTimer();
      _startVisualizerLoop();
    } catch (e) {
      debugPrint("Error playing audio stream: $e");
      _isPlaying = false;
      _isPlayingController.add(false);
      rethrow;
    }
  }

  Future<void> pause() async {
    if (!_initialized || _activeHandle == null) return;
    try {
      SoLoud.instance.pause(_activeHandle!);
      _isPlaying = false;
      _isPlayingController.add(false);
      _positionTimer?.cancel();
      _stopVisualizerLoop();
    } catch (e) {
      debugPrint("Error pausing playback: $e");
    }
  }

  Future<void> resume() async {
    if (!_initialized || _activeHandle == null) return;
    try {
      if (SoLoud.instance.getPause(_activeHandle!)) {
        SoLoud.instance.setPause(_activeHandle!, false);
      }
      _isPlaying = true;
      _isPlayingController.add(true);
      _startPositionTimer();
      _startVisualizerLoop();
    } catch (e) {
      debugPrint("Error resuming playback: $e");
    }
  }

  Future<void> stop() async {
    _positionTimer?.cancel();
    _stopVisualizerLoop();
    _isPlaying = false;
    _isPlayingController.add(false);
    _currentUrlOrPath = null;

    if (!_initialized) return;

    try {
      if (_activeHandle != null) {
        SoLoud.instance.stop(_activeHandle!);
        _activeHandle = null;
      }
      if (_activeSource != null) {
        await SoLoud.instance.disposeSource(_activeSource!);
        _activeSource = null;
      }
    } catch (e) {
      debugPrint("Error stopping audio: $e");
    }

    // Clean up temporary streaming file if any
    try {
      if (_tempStreamingFile != null && await _tempStreamingFile!.exists()) {
        await _tempStreamingFile!.delete();
        _tempStreamingFile = null;
      }
    } catch (_) {}
  }

  /// Seek to a specific position in seconds
  Future<void> seek(double positionInSeconds) async {
    if (!_initialized || _activeHandle == null) return;
    try {
      SoLoud.instance.seek(_activeHandle!, Duration(milliseconds: (positionInSeconds * 1000).toInt()));
    } catch (e) {
      debugPrint("Error seeking: $e");
    }
  }

  Duration getPosition() {
    if (!_initialized || _activeHandle == null) return Duration.zero;
    try {
      return SoLoud.instance.getPosition(_activeHandle!);
    } catch (e) {
      return Duration.zero;
    }
  }

  Duration getLength() {
    if (!_initialized || _activeSource == null) return Duration.zero;
    try {
      return SoLoud.instance.getLength(_activeSource!);
    } catch (e) {
      return Duration.zero;
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_initialized && _activeHandle != null && _isPlaying) {
        try {
          final pos = SoLoud.instance.getPosition(_activeHandle!).inMilliseconds / 1000.0;
          _playbackPositionController.add(pos);
        } catch (_) {}
      }
    });
  }

  /// Simple live audio visualizer stream loop (mock or real if FFT is enabled in flutter_soloud)
  void _startVisualizerLoop() {
    _visualizerTimer?.cancel();
    final random = Random();
    _visualizerTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_isPlaying) {
        final List<double> wave = List.generate(20, (index) {
          final double base = sin(index * 0.4 + DateTime.now().millisecondsSinceEpoch * 0.005);
          final double noise = random.nextDouble() * 0.3;
          final double scale = (_targetHz / 440.0); // Visuals shift speed/vibe based on current frequency!
          return (base.abs() * 0.7 + noise) * scale;
        });
        _visualizerController.add(wave);
      } else {
        _stopVisualizerLoop();
      }
    });
  }

  void _stopVisualizerLoop() {
    _visualizerTimer?.cancel();
    _visualizerTimer = null;
    // Emit empty wave state
    _visualizerController.add(List.filled(20, 0.05));
  }

  Future<void> dispose() async {
    await stop();
    _positionTimer?.cancel();
    _visualizerTimer?.cancel();
    await _playbackPositionController.close();
    await _isPlayingController.close();
    await _visualizerController.close();
    if (_initialized) {
      await SoLoud.instance.deinit();
    }
  }
}
