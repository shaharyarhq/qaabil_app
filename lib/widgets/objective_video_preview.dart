import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../screens/lesson_video_screen.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';

/// Shows an objective's approved videos when its chapter is opened.
class ObjectiveVideoPreview extends StatefulWidget {
  const ObjectiveVideoPreview({
    super.key,
    required this.objectiveId,
    required this.footer,
  });

  final int objectiveId;
  final Widget Function(List<LessonNote>) footer;

  @override
  State<ObjectiveVideoPreview> createState() => _ObjectiveVideoPreviewState();
}

class _ObjectiveVideoPreviewState extends State<ObjectiveVideoPreview> {
  Future<ObjectiveResources>? _resources;
  int? _memberId;
  int? _visibilityVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (_memberId != session.member?.id ||
        _visibilityVersion != session.contentVisibilityVersion) {
      _memberId = session.member?.id;
      _visibilityVersion = session.contentVisibilityVersion;
      _resources = _memberId == null
          ? null
          : session.resources(widget.objectiveId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.member == null) return const SizedBox.shrink();
    return FutureBuilder<ObjectiveResources>(
      future: _resources,
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _preview(session, snapshot),
          ),
          widget.footer(snapshot.data?.notes ?? const []),
        ],
      ),
    );
  }

  Widget _preview(
    MemberSession session,
    AsyncSnapshot<ObjectiveResources> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const LinearProgressIndicator();
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error is ApiException ? error.message : 'Could not load videos.',
          ),
          TextButton(
            onPressed: () => setState(() {
              _resources = session.resources(widget.objectiveId);
            }),
            child: const Text('Retry videos'),
          ),
        ],
      );
    }
    final videos = snapshot.data?.videos ?? const <LessonVideo>[];
    if (videos.isEmpty) {
      return const Text(
        'No approved videos yet.',
        style: AppTextStyles.caption,
      );
    }
    return _VideoCarousel(videos: videos);
  }
}

class _VideoCarousel extends StatefulWidget {
  const _VideoCarousel({required this.videos});

  final List<LessonVideo> videos;

  @override
  State<_VideoCarousel> createState() => _VideoCarouselState();
}

class _VideoCarouselState extends State<_VideoCarousel> {
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double distance) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + distance).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = AppSpacing.md;
      final width = math.min(220.0, constraints.maxWidth);
      final thumbnailHeight = width * 130 / 220;
      final height =
          thumbnailHeight + MediaQuery.textScalerOf(context).scale(66) + 24;
      final max =
          (width + gap) * widget.videos.length - gap - constraints.maxWidth;
      return Semantics(
        label: pluralize(widget.videos.length, 'video'),
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ListView.separated(
                controller: _scroll,
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemCount: widget.videos.length,
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (context, index) => SizedBox(
                  width: width,
                  child: ObjectiveVideoCard(
                    video: widget.videos[index],
                    thumbnailHeight: thumbnailHeight,
                  ),
                ),
              ),
              if (max > 1)
                AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, _) {
                    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (offset > 1)
                          _carouselArrow(
                            tooltip: 'Previous videos',
                            icon: Icons.chevron_left,
                            distance: -width - gap,
                          )
                        else
                          const SizedBox(width: 36),
                        if (offset < max - 1)
                          _carouselArrow(
                            tooltip: 'Next videos',
                            icon: Icons.chevron_right,
                            distance: width + gap,
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _carouselArrow({
    required String tooltip,
    required IconData icon,
    required double distance,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: () => _move(distance),
    style: IconButton.styleFrom(
      backgroundColor: AppPalette.of(context).surface,
      foregroundColor: AppPalette.of(context).accent,
      side: BorderSide(color: AppPalette.of(context).border),
      minimumSize: const Size(36, 36),
      padding: EdgeInsets.zero,
    ),
    icon: Icon(icon, size: 20),
  );
}

class ObjectiveVideoCard extends StatelessWidget {
  const ObjectiveVideoCard({
    super.key,
    required this.video,
    this.thumbnailHeight,
  });

  final LessonVideo video;
  final double? thumbnailHeight;

  @override
  Widget build(BuildContext context) {
    final rating = video.averageRating;
    const placeholder = ColoredBox(
      color: AppColors.navyDark,
      child: Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 38),
      ),
    );
    const ratingAmber = Color(0xFFF59E0B);
    final metadataStyle = AppTextStyles.caption.copyWith(
      color: Colors.white70,
      fontSize: 10,
    );
    final full = thumbnailHeight == null;
    final thumbnail = video.thumbnail == null
        ? placeholder
        : Image.network(
            video.thumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(full ? 16 : 12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonVideoScreen(videoId: video.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (full)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbnail,
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60F172A),
                          border: Border.all(color: const Color(0x66F59E0B)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Approved',
                          style: AppTextStyles.caption.copyWith(
                            color: ratingAmber,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(height: thumbnailHeight, child: thumbnail),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: full ? 16 : 12,
                vertical: full ? 12 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontSize: full ? 14 : 11.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (rating == null)
                    Text(
                      'No ratings yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metadataStyle.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Semantics(
                      label:
                          '${rating.toStringAsFixed(1)} out of 5, '
                          '${pluralize(video.reviewCount, 'review')}',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var star = 1; star <= 5; star++)
                            Icon(
                              star <= rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 13,
                              color: star <= rating.round()
                                  ? ratingAmber
                                  : Colors.white38,
                            ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              '${rating.toStringAsFixed(1)} (${video.reviewCount})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metadataStyle.copyWith(color: ratingAmber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (full) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 6,
                      children: [
                        if (video.creator case final creator?)
                          Flexible(
                            child: Text(
                              creator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metadataStyle,
                            ),
                          ),
                        if (video.submittedAt case final date?)
                          Flexible(
                            child: Text(
                              timeAgo(date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metadataStyle,
                            ),
                          ),
                      ],
                    ),
                  ] else if (video.creator != null)
                    Text(
                      video.creator!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metadataStyle,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
