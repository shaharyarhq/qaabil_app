import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../models/video_details.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/content_report_button.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/video_information.dart';
import '../widgets/video_reviews.dart';
import '../widgets/youtube_video.dart';
import '../widgets/bunny_video.dart';
import 'courses_screen.dart';
import 'member_course_screen.dart';

class LessonVideoScreen extends StatefulWidget {
  const LessonVideoScreen({super.key, required this.videoId});
  final int videoId;
  @override
  State<LessonVideoScreen> createState() => _LessonVideoScreenState();
}

class _LessonVideoScreenState extends State<LessonVideoScreen> {
  Future<VideoPlayback>? _video;
  Future<VideoDetails>? _details;
  _LessonTab _tab = _LessonTab.overview;
  bool _reviewsOpened = false;
  int? _memberId;
  int? _visibilityVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (session.member?.id != _memberId ||
        _visibilityVersion != session.contentVisibilityVersion) {
      final changedMember = _memberId != session.member?.id;
      _memberId = session.member?.id;
      _visibilityVersion = session.contentVisibilityVersion;
      _video = _memberId == null ? null : session.video(widget.videoId);
      _details = _memberId == null ? null : _loadDetails(session);
      if (changedMember) {
        _tab = _LessonTab.overview;
        _reviewsOpened = false;
      }
    }
  }

  Future<VideoDetails> _loadDetails(MemberSession session) {
    final future = session.videoDetails(widget.videoId);
    // Details can fail before the independently loaded player has built its panels.
    // Attach a listener now; FutureBuilder will still show the error and retry UI.
    future.ignore();
    return future;
  }

  Widget _information(
    MemberSession session,
    AsyncSnapshot<VideoDetails> snapshot,
    bool compact,
  ) {
    final details = snapshot.data;
    final files = details?.materials ?? const <VideoMaterial>[];
    final materialCount = files
        .where((file) => file.kind == 'learning_materials')
        .length;
    final tabs = [
      (_LessonTab.overview, 'Overview', 0),
      if (materialCount > 0)
        (
          _LessonTab.materials,
          compact ? 'Materials' : 'Learning materials',
          materialCount,
        ),
      if (files.any((file) => file.kind == 'quiz_attachments') ||
          details?.quizUrl != null)
        (_LessonTab.videoNotes, 'Video notes', 0),
      if (files.any((file) => file.kind == 'objective_notes'))
        (
          _LessonTab.objectiveNotes,
          compact ? 'Objective' : 'Objective resources',
          0,
        ),
      (_LessonTab.reviews, 'Reviews', 0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppPalette.of(context).border),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (tab, label, count) in tabs)
                  Semantics(
                    selected: tab == _tab,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: tab == _tab
                                ? const Color(0xFFF59E0B)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: tab == _tab
                              ? AppPalette.of(context).accent
                              : AppPalette.of(context).textMuted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          minimumSize: const Size(0, 44),
                          textStyle: AppTextStyles.label.copyWith(
                            fontSize: compact ? 12 : 14,
                          ),
                          shape: const RoundedRectangleBorder(),
                        ),
                        onPressed: () => setState(() {
                          _tab = tab;
                          if (tab == _LessonTab.reviews) _reviewsOpened = true;
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            Text(label),
                            if (count > 0)
                              Badge(
                                backgroundColor: AppColors.navy,
                                label: Text('$count'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_reviewsOpened)
          Visibility(
            visible: _tab == _LessonTab.reviews,
            maintainState: true,
            child: VideoReviews(
              key: ValueKey('${widget.videoId}/$_memberId'),
              videoId: widget.videoId,
            ),
          ),
        if (_tab != _LessonTab.reviews)
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError)
            Column(
              children: [
                Text(
                  snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Could not load video details.',
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _details = _loadDetails(session);
                    });
                  },
                  child: const Text('Retry details'),
                ),
              ],
            )
          else if (details != null)
            switch (_tab) {
              _LessonTab.overview => VideoOverview(details: details),
              _ => VideoMaterials(
                key: ValueKey(_tab),
                videoId: widget.videoId,
                files: files
                    .where((file) => file.kind == _tab.materialKind)
                    .toList(),
                quizUrl: _tab == _LessonTab.videoNotes ? details.quizUrl : null,
              ),
            },
      ],
    );
  }

  Widget _lesson(
    VideoPlayback video,
    VideoDetails? details,
    bool compact,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (video.bunnyEmbedUrl case final url?)
        BunnyVideo(key: ValueKey(url), url: url)
      else if (video.allowed && video.youtubeId != null)
        YoutubeVideo(videoId: video.youtubeId!)
      else
        Container(
          constraints: const BoxConstraints(minHeight: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.amber),
              Text(
                video.reason == 'unsupported_source'
                    ? 'This video format is not supported in the app yet.'
                    : 'Playback is not available in this build yet.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                video.title,
                style: TextStyle(
                  fontFamily: AppTextStyles.serif,
                  color: AppPalette.of(context).textPrimary,
                  fontSize: compact ? 28 : 38,
                  height: 1.1,
                ),
              ),
            ),
          ),
          if (details != null) ...[
            const SizedBox(width: 8),
            VideoStatusBadge(status: details.status),
          ],
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (details?.submittedAt case final date?)
            Text('Submitted ${timeAgo(date)}', style: AppTextStyles.caption),
          if (video.creator case final creator?)
            Text(
              creator,
              style: AppTextStyles.caption.copyWith(
                color: AppPalette.of(context).textSecondary,
              ),
            ),
          if (details?.language case final language?
              when language.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppPalette.of(context).navyTint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Icon(
                    Icons.language,
                    size: 13,
                    color: AppPalette.of(context).accent,
                  ),
                  Text(
                    language,
                    style: AppTextStyles.caption.copyWith(
                      color: AppPalette.of(context).accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (details?.status == 'approved')
        Align(
          alignment: Alignment.centerLeft,
          child: ContentReportButton(videoId: widget.videoId),
        ),
    ],
  );

  Widget _breadcrumb(VideoDetails details) => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      InkWell(
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CoursesScreen()),
        ),
        child: const Text('Courses', style: AppTextStyles.caption),
      ),
      const _BreadcrumbSeparator(),
      InkWell(
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MemberCourseScreen(courseId: details.course.id),
          ),
        ),
        child: Text(details.course.name, style: AppTextStyles.caption),
      ),
      for (final name in [
        details.section.name,
        details.chapter.name,
        details.objective.name,
      ]) ...[
        const _BreadcrumbSeparator(),
        Text(
          name,
          style: AppTextStyles.caption.copyWith(
            color: AppPalette.of(context).textSecondary,
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: MediaQuery.sizeOf(context).width >= 640
          ? const QaabilAppBar(height: 76, logoHeight: 44)
          : const QaabilAppBar(),
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
                return SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final compact = width < 640;
                      final wide = width >= 1280;
                      final inset = math.max(
                        compact ? 16.0 : 24.0,
                        (width - 1280) / 2 + 24,
                      );
                      return FutureBuilder<VideoDetails>(
                        future: _details,
                        builder: (context, snapshot) {
                          final details = snapshot.data;
                          final main = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _lesson(video, details, compact),
                              const SizedBox(height: AppSpacing.xl),
                              _information(session, snapshot, compact),
                            ],
                          );
                          final related = details == null
                              ? const SizedBox.shrink()
                              : RelatedVideos(details: details, vertical: wide);
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              inset,
                              compact ? 24 : 40,
                              inset,
                              48,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                details == null
                                    ? const SizedBox.shrink()
                                    : _breadcrumb(details),
                                SizedBox(
                                  height: details == null ? 0 : AppSpacing.xxl,
                                ),
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 32,
                                    children: [
                                      Expanded(child: main),
                                      SizedBox(width: 320, child: related),
                                    ],
                                  )
                                else ...[
                                  main,
                                  const SizedBox(height: AppSpacing.xxl),
                                  related,
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

enum _LessonTab {
  overview,
  materials,
  videoNotes,
  objectiveNotes,
  reviews;

  String? get materialKind => switch (this) {
    materials => 'learning_materials',
    videoNotes => 'quiz_attachments',
    objectiveNotes => 'objective_notes',
    _ => null,
  };
}

class _BreadcrumbSeparator extends StatelessWidget {
  const _BreadcrumbSeparator();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Icon(Icons.auto_awesome, size: 10, color: Color(0xFFF59E0B)),
  );
}
