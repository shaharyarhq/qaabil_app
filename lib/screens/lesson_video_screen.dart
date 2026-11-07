import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../models/video_details.dart';
import '../widgets/video_reviews.dart';
import '../widgets/video_information.dart';
import '../services/member_api.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/youtube_video.dart';

class LessonVideoScreen extends StatefulWidget {
  const LessonVideoScreen({super.key, required this.videoId});
  final int videoId;
  @override
  State<LessonVideoScreen> createState() => _LessonVideoScreenState();
}

class _LessonVideoScreenState extends State<LessonVideoScreen> {
  Future<VideoPlayback>? _video;
  Future<VideoDetails>? _details;
  String _tab = 'Overview';
  bool _reviewsOpened = false;
  int? _memberId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (session.member?.id != _memberId) {
      _memberId = session.member?.id;
      _video = _memberId == null ? null : session.video(widget.videoId);
      _details = _memberId == null ? null : _loadDetails(session);
      _tab = 'Overview';
      _reviewsOpened = false;
    }
  }

  Future<VideoDetails> _loadDetails(MemberSession session) {
    final future = session.videoDetails(widget.videoId);
    // Details can fail before the independently loaded player has built its panels.
    // Attach a listener now; FutureBuilder will still show the error and retry UI.
    future.ignore();
    return future;
  }

  Widget _information(MemberSession session) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AppSpacing.xl),
      FutureBuilder<VideoDetails>(
        future: _details,
        builder: (context, snapshot) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tab in [
                'Overview',
                'Reviews',
                if (snapshot.data?.materials.isNotEmpty == true ||
                    snapshot.data?.quizUrl != null)
                  'Materials',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(tab),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() {
                      _tab = tab;
                      if (tab == 'Reviews') _reviewsOpened = true;
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_reviewsOpened)
        Visibility(
          visible: _tab == 'Reviews',
          maintainState: true,
          child: VideoReviews(
            key: ValueKey('${widget.videoId}/$_memberId'),
            videoId: widget.videoId,
          ),
        ),
      if (_tab != 'Reviews')
        FutureBuilder<VideoDetails>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  Text(
                    snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Could not load video details.',
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _details = _loadDetails(session)),
                    child: const Text('Retry details'),
                  ),
                ],
              );
            }
            final details = snapshot.data;
            if (details == null) return const SizedBox.shrink();
            return _tab == 'Materials'
                ? VideoMaterials(videoId: widget.videoId, details: details)
                : VideoOverview(details: details);
          },
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: session.member == null
          ? const Center(child: Text('Log in again to watch this video.'))
          : FutureBuilder<VideoPlayback>(
              future: _video,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error is ApiException
                                ? error.message
                                : 'Could not load this video.',
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _video = session.video(widget.videoId);
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final video = snapshot.data;
                if (video == null) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.contentMaxWidth,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      children: [
                        FutureBuilder<VideoDetails>(
                          future: _details,
                          builder: (context, snapshot) {
                            final details =
                                snapshot.connectionState == ConnectionState.done
                                ? snapshot.data
                                : null;
                            return details == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child: Text(
                                      '${details.course.name} → ${details.section.name} → ${details.chapter.name} → ${details.objective.name}',
                                      style: AppTextStyles.caption,
                                    ),
                                  );
                          },
                        ),
                        Text(video.title, style: AppTextStyles.heading),
                        if (video.creator != null)
                          Text(
                            'By ${video.creator}',
                            style: AppTextStyles.body,
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        if (video.allowed)
                          YoutubeVideo(videoId: video.youtubeId!)
                        else
                          Column(
                            children: [
                              const Icon(Icons.lock_outline, size: 48),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                video.reason == 'unsupported_source'
                                    ? 'This video format is not supported in the app yet.'
                                    : 'Playback is not available in this build yet.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        _information(session),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
