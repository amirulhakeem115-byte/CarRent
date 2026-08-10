import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/colors.dart';
import 'web_video_player_helper.dart';

/// Interactive, full-featured video player for streaming return evidence videos.
/// Supports Web, Mobile, and Desktop with controls: Play, Pause, Seek, Duration/Position,
/// Volume/Mute, Fullscreen, Loading State, and Error Diagnostics.
class AppVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final String? originalFileName;
  final dynamic fileSize;
  final bool autoPlay;

  const AppVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.title,
    this.originalFileName,
    this.fileSize,
    this.autoPlay = false,
  });

  @override
  State<AppVideoPlayerWidget> createState() => _AppVideoPlayerWidgetState();
}

class _AppVideoPlayerWidgetState extends State<AppVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _errorDiagnostic = '';
  bool _isMuted = false;
  double _volume = 1.0;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposePlayer();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = '';
      _errorDiagnostic = '';
    });

    final String rawUrl = widget.videoUrl.trim();
    if (rawUrl.isEmpty) {
      _setError(
        'Empty Video URL',
        'The provided video stream URL is empty or null.',
      );
      return;
    }

    // Format & extension diagnostic check
    final ext = rawUrl.contains('.')
        ? rawUrl.split('?').first.split('.').last.toLowerCase()
        : '';
    debugPrint('[AppVideoPlayerWidget] Initializing video player for URL: $rawUrl (ext: $ext)');

    try {
      final Uri uri = Uri.parse(rawUrl);
      _controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _controller!.addListener(_onControllerUpdate);

      await _controller!.initialize().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw TimeoutException(
            'Video connection timed out after 25 seconds. Please check your internet connection or Firebase Storage URL.',
          );
        },
      );

      if (!mounted) return;

      if (_controller!.value.hasError) {
        final errText = _controller!.value.errorDescription ?? 'Unknown Video Error';
        _setError(
          'Unable to play this video.',
          'Player Engine Error: $errText\nURL: $rawUrl\nFormat: ${ext.toUpperCase()}',
        );
        return;
      }

      setState(() {
        _isInitializing = false;
      });

      if (widget.autoPlay) {
        _controller!.play();
      }

      _startHideControlsTimer();
    } catch (e, stack) {
      debugPrint('[AppVideoPlayerWidget] Initialization Exception: $e\nStack: $stack');
      
      String diagInfo = 'Diagnostic Information:\n';
      diagInfo += '• Platform: ${kIsWeb ? "Web Browser" : "Native App"}\n';
      diagInfo += '• File Extension: .${ext.isEmpty ? "unknown" : ext}\n';
      diagInfo += '• Raw Error: ${e.toString()}\n';
      
      if (rawUrl.contains('firebasestorage.googleapis.com')) {
        diagInfo += '• Firebase Storage URL verified: Yes\n';
        if (!rawUrl.contains('alt=media')) {
          diagInfo += '• Warning: Missing alt=media query parameter.\n';
        }
      } else {
        diagInfo += '• Non-Firebase Storage URL.\n';
      }

      _setError(
        'Unable to play this video.',
        diagInfo,
      );
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (_controller != null && _controller!.value.hasError && !_hasError) {
      final err = _controller!.value.errorDescription ?? 'Playback Failure';
      _setError('Unable to play this video.', 'Runtime Playback Error: $err');
    } else {
      setState(() {});
    }
  }

  void _setError(String msg, String diag) {
    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      _hasError = true;
      _errorMessage = msg;
      _errorDiagnostic = diag;
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller!.play();
        _startHideControlsTimer();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : _volume);
    });
  }

  void _setVolume(double value) {
    if (_controller == null) return;
    setState(() {
      _volume = value;
      _isMuted = value == 0;
      _controller!.setVolume(value);
    });
  }

  void _toggleFullscreen() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(widget.title ?? 'Return Video Evidence'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: AppVideoPlayerWidget(
              videoUrl: widget.videoUrl,
              title: widget.title,
              autoPlay: true,
            ),
          ),
        ),
      ),
    );
  }

  void _disposePlayer() {
    _hideControlsTimer?.cancel();
    if (_controller != null) {
      _controller!.removeListener(_onControllerUpdate);
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatFileSizeDisplay(dynamic size) {
    if (size == null) return '';
    final int bytes = size is int ? size : (int.tryParse(size.toString()) ?? 0);
    if (bytes <= 0) return '';
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (kIsWeb) {
      return Container(
        height: 380,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: buildWebVideoPlayer(
          videoUrl: widget.videoUrl,
          autoPlay: widget.autoPlay,
        ),
      );
    }

    if (_isInitializing) {
      return Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                  strokeWidth: 3.5,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Loading video evidence...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Connecting to Firebase Storage stream...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                  tooltip: 'Retry Loading Video',
                  onPressed: _initializePlayer,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black45 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diagnostic Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _errorDiagnostic,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;
    final isPlaying = controller.value.isPlaying;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video Surface
          GestureDetector(
            onTap: _toggleControlsVisibility,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),

          // Controls Overlay
          if (_showControls || !isPlaying)
            AnimatedOpacity(
              opacity: _showControls || !isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar Header
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam_rounded, color: AppColors.primaryOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.title ?? 'Return Video Evidence',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.fileSize != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatFileSizeDisplay(widget.fileSize),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                            tooltip: 'Fullscreen View',
                            onPressed: _toggleFullscreen,
                          ),
                        ],
                      ),
                    ),

                    // Center Big Play/Pause Action
                    IconButton(
                      iconSize: 56,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppColors.primaryOrange,
                      ),
                      onPressed: _togglePlayPause,
                    ),

                    // Bottom Control Toolbar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Interactive Scrubber Slider
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: AppColors.primaryOrange,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.primaryOrange,
                            ),
                            child: Slider(
                              value: position.inMilliseconds.toDouble().clamp(
                                    0.0,
                                    duration.inMilliseconds.toDouble(),
                                  ),
                              min: 0.0,
                              max: duration.inMilliseconds.toDouble() > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1.0,
                              onChanged: (val) {
                                controller.seekTo(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),

                          // Control Action Buttons Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      _isMuted || _volume == 0
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _toggleMute,
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: SliderTheme(
                                      data: const SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        value: _isMuted ? 0.0 : _volume,
                                        onChanged: _setVolume,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
