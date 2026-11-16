import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../models/video_details.dart';
import '../screens/lesson_video_screen.dart';
import '../screens/member_course_screen.dart';
import '../screens/objective_resources_screen.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';

class VideoStatusBadge extends StatelessWidget {
  const VideoStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (text, color, tint) = switch (status) {
      'approved' => (
        'Approved',
        AppPalette.of(context).amberText,
        AppPalette.of(context).amberTint,
      ),
      'pending' => (
        'Pending review',
        AppPalette.of(context).textMuted,
        AppPalette.of(context).navyTint,
      ),
      _ => (
        status,
        AppPalette.of(context).error,
        AppPalette.of(context).coralTint,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: color.withValues(alpha: .22)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.pill.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class VideoOverview extends StatelessWidget {
  const VideoOverview({super.key, required this.details});

  final VideoDetails details;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (Icons.verified_outlined, 'Objective', details.objective.name),
      (Icons.menu_book_outlined, 'Chapter', details.chapter.name),
      (Icons.view_list_outlined, 'Section', details.section.name),
      if (details.approvedBy case final name?)
        (Icons.person_outline, 'Approved by', name),
      if (details.submittedAt case final date?)
        (
          Icons.calendar_today_outlined,
          'Submitted',
          MaterialLocalizations.of(context).formatMediumDate(date.toLocal()),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (details.description.trim().isNotEmpty)
          VideoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text('ABOUT THIS SUBMISSION', style: _eyebrow(context)),
                Text(details.description, style: AppTextStyles.body),
              ],
            ),
          ),
        VideoPanel(
          child: Column(
            children: [
              for (final (index, (icon, label, value)) in rows.indexed) ...[
                if (index > 0)
                  Divider(height: 24, color: AppPalette.of(context).border),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    _VideoIcon(icon: icon, amber: true),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label.toUpperCase(), style: _eyebrow(context)),
                          Text(
                            value,
                            style: AppTextStyles.label.copyWith(
                              color: AppPalette.of(context).textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class RelatedVideos extends StatelessWidget {
  const RelatedVideos({
    super.key,
    required this.details,
    required this.vertical,
  });

  final VideoDetails details;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final video in details.related)
        _RelatedCard(video: video, vertical: vertical),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text('MORE FROM THIS OBJECTIVE', style: _eyebrow(context)),
        if (cards.isEmpty)
          const Text('No other submissions yet.', style: AppTextStyles.caption)
        else if (vertical)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: cards,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                for (final card in cards) SizedBox(width: 220, child: card),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    ObjectiveResourcesScreen(objectiveId: details.objective.id),
              ),
            ),
            child: Text(
              details.relatedTotal > details.related.length
                  ? 'See all videos for this objective'
                  : 'All objective resources',
            ),
          ),
        ),
        Divider(height: 1, color: AppPalette.of(context).border),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.chevron_left, size: 18),
            label: Text('Back to ${details.course.name}'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MemberCourseScreen(courseId: details.course.id),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.video, required this.vertical});

  final LessonVideo video;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    const fallback = Center(
      child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 24),
    );
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFF0F172A),
        child: SizedBox(
          width: vertical ? 96 : double.infinity,
          height: vertical ? 60 : 120,
          child: video.thumbnail == null
              ? fallback
              : Image.network(
                  video.thumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label.copyWith(
            color: AppPalette.of(context).textPrimary,
          ),
        ),
        if (video.averageRating case final rating?)
          Wrap(
            spacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 1; index <= 5; index++)
                Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: index <= rating.round()
                      ? const Color(0xFFF59E0B)
                      : AppPalette.of(context).border,
                ),
              Text(
                '${rating.toStringAsFixed(1)} (${video.reviewCount})',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const VideoStatusBadge(status: 'approved'),
            if (video.submittedAt case final date?)
              Text(timeAgo(date), style: AppTextStyles.caption),
          ],
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppPalette.of(context).navyTint,
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LessonVideoScreen(videoId: video.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: vertical
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    thumbnail,
                    Expanded(child: summary),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [thumbnail, summary],
                ),
        ),
      ),
    );
  }
}

class VideoMaterials extends StatefulWidget {
  const VideoMaterials({
    super.key,
    required this.videoId,
    required this.files,
    this.quizUrl,
  });

  final int videoId;
  final List<VideoMaterial> files;
  final Uri? quizUrl;

  @override
  State<VideoMaterials> createState() => _VideoMaterialsState();
}

class _VideoMaterialsState extends State<VideoMaterials> {
  String? _opening;
  String? _error;

  Future<void> _open(VideoMaterial file) async {
    if (_opening != null) return;
    setState(() {
      _opening = '${file.kind}/${file.id}';
      _error = null;
    });
    try {
      await SessionScope.of(context).openVideoMaterial(widget.videoId, file);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException
              ? error.message
              : 'Could not open this material.';
        });
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _quiz() async {
    final link = widget.quizUrl;
    if (link == null) return;
    setState(() => _error = null);
    try {
      if (!await launchUrl(link, mode: LaunchMode.externalApplication)) {
        throw const ApiException('No browser could open this quiz.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the quiz in your browser.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      if (_error case final error?)
        Text(
          error,
          style: AppTextStyles.body.copyWith(
            color: AppPalette.of(context).error,
          ),
        ),
      if (widget.quizUrl case final url?)
        Material(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: const _VideoIcon(
              icon: Icons.fact_check_outlined,
              amber: true,
            ),
            title: Text(
              'Take the quiz',
              style: AppTextStyles.label.copyWith(color: Colors.white),
            ),
            subtitle: Text(
              'Opens ${url.host} in your browser',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            trailing: const Icon(
              Icons.open_in_new,
              size: 16,
              color: Colors.white70,
            ),
            onTap: _quiz,
          ),
        ),
      for (final file in widget.files)
        VideoPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: _VideoIcon(
              icon: file.mime.startsWith('image/')
                  ? Icons.image_outlined
                  : Icons.description_outlined,
              amber: file.kind == 'quiz_attachments',
            ),
            title: Text(
              file.name,
              style: AppTextStyles.label.copyWith(
                color: AppPalette.of(context).textPrimary,
              ),
            ),
            subtitle: Text(
              _opening == '${file.kind}/${file.id}'
                  ? 'Opening…'
                  : '${file.label} · ${(file.size / 1024).ceil()} KB',
              style: AppTextStyles.caption,
            ),
            trailing: Icon(
              file.kind == 'objective_notes'
                  ? Icons.download_outlined
                  : Icons.open_in_new,
              size: 16,
              color: AppPalette.of(context).textMuted,
            ),
            onTap: _opening == null ? () => _open(file) : null,
          ),
        ),
    ],
  );
}

TextStyle _eyebrow(BuildContext context) => AppTextStyles.eyebrow.copyWith(
  color: AppPalette.of(context).textMuted,
  letterSpacing: .8,
  fontSize: 11,
);

class VideoPanel extends StatelessWidget {
  const VideoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.of(context).surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: AppPalette.of(context).border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class _VideoIcon extends StatelessWidget {
  const _VideoIcon({required this.icon, required this.amber});

  final IconData icon;
  final bool amber;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: amber
          ? AppPalette.of(context).amberTint
          : AppPalette.of(context).navyTint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      icon,
      color: amber
          ? AppPalette.of(context).amberText
          : AppPalette.of(context).accent,
      size: 16,
    ),
  );
}
