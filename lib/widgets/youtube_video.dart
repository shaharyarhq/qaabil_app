import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../theme/app_tokens.dart';

/// An inline YouTube lesson, with a fresh player on retry or lesson change.
class YoutubeVideo extends StatefulWidget {
  const YoutubeVideo({super.key, required this.videoId});
  final String videoId;

  @override
  State<YoutubeVideo> createState() => _YoutubeVideoState();
}

class _YoutubeVideoState extends State<YoutubeVideo> {
  late YoutubePlayerController _controller;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _createPlayer();
  }

  void _createPlayer() {
    _loadFailed = false;
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    unawaited(_cueLesson(_controller, widget.videoId));
  }

  Future<void> _cueLesson(YoutubePlayerController controller, String id) async {
    try {
      // Await loading explicitly so initialization/network failures are handled.
      // The factory starts this Future without exposing its errors to the widget.
      await controller.cueVideoById(videoId: id);
    } catch (_) {
      if (mounted && controller == _controller) {
        setState(() => _loadFailed = true);
      }
    }
  }

  void _retry() {
    unawaited(_controller.close());
    setState(_createPlayer);
  }

  @override
  void didUpdateWidget(covariant YoutubeVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      unawaited(_controller.close());
      _createPlayer();
    }
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
      child: StreamBuilder<YoutubePlayerValue>(
        key: ValueKey(_controller),
        stream: _controller.stream,
        initialData: _controller.value,
        builder: (context, snapshot) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: AppRadius.button,
              child: LayoutBuilder(
                builder: (context, constraints) => YoutubePlayer(
                  key: ValueKey(_controller),
                  controller: _controller,
                  // Keep YouTube controls at least 200 logical pixels high on phones.
                  aspectRatio: math.min(16 / 9, constraints.maxWidth / 200),
                  autoFullScreen: false,
                ),
              ),
            ),
            if (_loadFailed || snapshot.data?.hasError == true) ...[
              const SizedBox(height: AppSpacing.md),
              const Text(
                'This video could not be played. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry video'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
