import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../theme/app_tokens.dart';

/// Plays one YouTube video inside the app, with rounded corners.
///
/// This is a StatefulWidget because the player has a *controller* that must
/// be created once and closed when the widget goes away (otherwise the
/// video could keep playing in the background).
class YoutubeVideo extends StatefulWidget {
  const YoutubeVideo({super.key, required this.videoId});

  /// The part after `v=` in a YouTube link.
  final String videoId;

  @override
  State<YoutubeVideo> createState() => _YoutubeVideoState();
}

class _YoutubeVideoState extends State<YoutubeVideo> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        // Only suggest videos from the same channel when it ends.
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.button,
      child: YoutubePlayer(
        controller: _controller,
        // By default the player jumps to fullscreen whenever the device is
        // in landscape. Keep it inline; the fullscreen button still works.
        autoFullScreen: false,
      ),
    );
  }
}
