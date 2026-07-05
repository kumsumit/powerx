import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

enum RecordingQuality {
  low, // 480p
  medium, // 720p
  high, // 1080p
  ultra, // 4K
}

enum RecordingFormat { mp4, avi, mov, webm, gif }

class RecordingSettings {
  final RecordingQuality quality;
  final RecordingFormat format;
  final int fps;
  final bool recordAudio;
  final bool recordPointer;
  final bool recordAnnotations;
  final Rect? captureRegion;
  final bool includePresenterNotes;

  const RecordingSettings({
    this.quality = RecordingQuality.high,
    this.format = RecordingFormat.mp4,
    this.fps = 30,
    this.recordAudio = true,
    this.recordPointer = true,
    this.recordAnnotations = true,
    this.captureRegion,
    this.includePresenterNotes = false,
  });

  Size get resolution {
    switch (quality) {
      case RecordingQuality.low:
        return const Size(854, 480);
      case RecordingQuality.medium:
        return const Size(1280, 720);
      case RecordingQuality.high:
        return const Size(1920, 1080);
      case RecordingQuality.ultra:
        return const Size(3840, 2160);
    }
  }

  String get fileExtension {
    switch (format) {
      case RecordingFormat.mp4:
        return '.mp4';
      case RecordingFormat.avi:
        return '.avi';
      case RecordingFormat.mov:
        return '.mov';
      case RecordingFormat.webm:
        return '.webm';
      case RecordingFormat.gif:
        return '.gif';
    }
  }
}

class RecordingResult {
  final String name;
  final RecordingSettings settings;
  final Duration duration;
  final int frameCount;
  final int frameBytes;
  final Uint8List bytes;
  final DateTime createdAt;

  const RecordingResult({
    required this.name,
    required this.settings,
    required this.duration,
    required this.frameCount,
    required this.frameBytes,
    required this.bytes,
    required this.createdAt,
  });

  double get sizeMB => bytes.length / (1024 * 1024);
}

class ScreenRecorder extends ChangeNotifier {
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _elapsed = Duration.zero;
  RecordingSettings _settings = const RecordingSettings();
  Timer? _timer;
  DateTime? _startTime;
  DateTime? _pauseTime;
  int _frameCount = 0;
  final List<Uint8List> _frames = [];
  String? _outputPath;
  String? _error;
  RecordingResult? _lastResult;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  Duration get elapsed => _elapsed;
  RecordingSettings get settings => _settings;
  String? get outputPath => _outputPath;
  String? get error => _error;
  RecordingResult? get lastResult => _lastResult;
  int get frameCount => _frameCount;
  double get estimatedFileSizeMB {
    final totalBytes = _frames.fold<int>(0, (sum, frame) => sum + frame.length);
    return totalBytes / (1024 * 1024);
  }

  void setSettings(RecordingSettings settings) {
    if (_isRecording) return;
    _settings = settings;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      _isRecording = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _frameCount = 0;
      _frames.clear();
      _error = null;
      _outputPath = null;
      _lastResult = null;

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPaused) {
          _elapsed += const Duration(seconds: 1);
          notifyListeners();
        }
      });

      notifyListeners();
    } catch (e) {
      _error = 'Failed to start recording: $e';
      notifyListeners();
    }
  }

  void pauseRecording() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _pauseTime = DateTime.now();
    notifyListeners();
  }

  void resumeRecording() {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
    if (_pauseTime != null && _startTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseTime!);
      _startTime = _startTime!.add(pauseDuration);
    }
    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      _timer?.cancel();
      _isRecording = false;
      _isPaused = false;

      final createdAt = DateTime.now();
      final name =
          'recording_${createdAt.millisecondsSinceEpoch}${_settings.fileExtension}';
      final bytes = _buildRecordingPayload(name, createdAt);
      final frameBytes = _frames.fold<int>(
        0,
        (sum, frame) => sum + frame.length,
      );
      _lastResult = RecordingResult(
        name: name,
        settings: _settings,
        duration: _elapsed,
        frameCount: _frameCount,
        frameBytes: frameBytes,
        bytes: bytes,
        createdAt: createdAt,
      );
      _outputPath = 'memory://$name';
      _frames.clear();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to stop recording: $e';
      notifyListeners();
    }
  }

  void captureFrame(Uint8List frameData) {
    if (!_isRecording || _isPaused) return;
    _frames.add(Uint8List.fromList(frameData));
    _frameCount++;
  }

  Uint8List _buildRecordingPayload(String name, DateTime createdAt) {
    final buffer = BytesBuilder(copy: false);
    buffer.add(
      Uint8List.fromList(
        'PowerX Recording\n'
                'name=$name\n'
                'createdAt=${createdAt.toIso8601String()}\n'
                'format=${_settings.format.name}\n'
                'fps=${_settings.fps}\n'
                'durationMs=${_elapsed.inMilliseconds}\n'
                'frames=$_frameCount\n'
                'resolution=${_settings.resolution.width.toInt()}x${_settings.resolution.height.toInt()}\n\n'
            .codeUnits,
      ),
    );
    for (final frame in _frames) {
      buffer.add(_int32Bytes(frame.length));
      buffer.add(frame);
    }
    return buffer.toBytes();
  }

  Uint8List _int32Bytes(int value) {
    return Uint8List(4)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF
      ..[2] = (value >> 16) & 0xFF
      ..[3] = (value >> 24) & 0xFF;
  }

  void discardRecording() {
    _timer?.cancel();
    _isRecording = false;
    _isPaused = false;
    _elapsed = Duration.zero;
    _frameCount = 0;
    _frames.clear();
    _outputPath = null;
    _lastResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// Recording UI overlay
class RecordingOverlay extends StatelessWidget {
  final ScreenRecorder recorder;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const RecordingOverlay({
    super.key,
    required this.recorder,
    required this.onStop,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: recorder,
      builder: (context, child) {
        if (!recorder.isRecording) return const SizedBox.shrink();

        return Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recording indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                // Timer
                Text(
                  _formatDuration(recorder.elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 16),
                // Controls
                if (recorder.isPaused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: onResume,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.pause, color: Colors.white),
                    onPressed: onPause,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  onPressed: onStop,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Frame count
                Text(
                  '${recorder.frameCount} frames',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

// Recording settings dialog
class RecordingSettingsDialog extends StatefulWidget {
  final RecordingSettings initialSettings;
  final Function(RecordingSettings) onSave;

  const RecordingSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onSave,
  });

  @override
  State<RecordingSettingsDialog> createState() =>
      _RecordingSettingsDialogState();
}

class _RecordingSettingsDialogState extends State<RecordingSettingsDialog> {
  late RecordingSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recording Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quality
            const Text(
              'Quality',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<RecordingQuality>(
              value: _settings.quality,
              isExpanded: true,
              items: RecordingQuality.values.map((q) {
                return DropdownMenuItem(
                  value: q,
                  child: Text('${q.name} (${_getResolutionText(q)})'),
                );
              }).toList(),
              onChanged: (q) {
                if (q != null) {
                  setState(
                    () => _settings = RecordingSettings(
                      quality: q,
                      format: _settings.format,
                      fps: _settings.fps,
                      recordAudio: _settings.recordAudio,
                      recordPointer: _settings.recordPointer,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            // Format
            const Text('Format', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<RecordingFormat>(
              value: _settings.format,
              isExpanded: true,
              items: RecordingFormat.values.map((f) {
                return DropdownMenuItem(
                  value: f,
                  child: Text(f.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (f) {
                if (f != null) {
                  setState(
                    () => _settings = RecordingSettings(
                      quality: _settings.quality,
                      format: f,
                      fps: _settings.fps,
                      recordAudio: _settings.recordAudio,
                      recordPointer: _settings.recordPointer,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            // FPS
            const Text(
              'Frame Rate',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _settings.fps.toDouble(),
              min: 15,
              max: 60,
              divisions: 9,
              label: '${_settings.fps} FPS',
              onChanged: (v) {
                setState(
                  () => _settings = RecordingSettings(
                    quality: _settings.quality,
                    format: _settings.format,
                    fps: v.toInt(),
                    recordAudio: _settings.recordAudio,
                    recordPointer: _settings.recordPointer,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Options
            CheckboxListTile(
              title: const Text('Record Audio'),
              value: _settings.recordAudio,
              onChanged: (v) {
                setState(
                  () => _settings = RecordingSettings(
                    quality: _settings.quality,
                    format: _settings.format,
                    fps: _settings.fps,
                    recordAudio: v ?? true,
                    recordPointer: _settings.recordPointer,
                  ),
                );
              },
            ),
            CheckboxListTile(
              title: const Text('Record Pointer'),
              value: _settings.recordPointer,
              onChanged: (v) {
                setState(
                  () => _settings = RecordingSettings(
                    quality: _settings.quality,
                    format: _settings.format,
                    fps: _settings.fps,
                    recordAudio: _settings.recordAudio,
                    recordPointer: v ?? true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_settings);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _getResolutionText(RecordingQuality quality) {
    switch (quality) {
      case RecordingQuality.low:
        return '854x480';
      case RecordingQuality.medium:
        return '1280x720';
      case RecordingQuality.high:
        return '1920x1080';
      case RecordingQuality.ultra:
        return '3840x2160';
    }
  }
}
