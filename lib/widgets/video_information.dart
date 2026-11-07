import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/member_session.dart';
import '../models/video_details.dart';
import '../screens/member_course_screen.dart';
import '../screens/objective_resources_screen.dart';
import '../screens/lesson_video_screen.dart';
import '../services/member_api.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

class VideoOverview extends StatelessWidget {
  const VideoOverview({super.key, required this.details});
  final VideoDetails details;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('About this submission', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            Text(
              details.description.isEmpty
                  ? 'No description has been added yet.'
                  : details.description,
            ),
            const Divider(height: 32),
            Text('Status: ${details.status}'),
            if (details.language?.isNotEmpty == true)
              Text('Language: ${details.language}'),
            if (details.submittedAt != null)
              Text(
                'Submitted: ${details.submittedAt!.toLocal().toIso8601String().split('T').first}',
              ),
            if (details.approvedBy != null)
              Text('Approved by: ${details.approvedBy}'),
            const SizedBox(height: AppSpacing.md),
            Text('Section: ${details.section.name}'),
            Text('Chapter: ${details.chapter.name}'),
            Text('Objective: ${details.objective.name}'),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      MemberCourseScreen(courseId: details.course.id),
                ),
              ),
              child: Text('Back to ${details.course.name}'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ObjectiveResourcesScreen(
                    objectiveId: details.objective.id,
                  ),
                ),
              ),
              child: const Text('All objective resources'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      const Text('More from this objective', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.md),
      if (details.related.isEmpty) const Text('No other submissions yet.'),
      for (final video in details.related)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(video.title, style: AppTextStyles.label),
                if (video.creator != null) Text('By ${video.creator}'),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LessonVideoScreen(videoId: video.id),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Open related video'),
                ),
              ],
            ),
          ),
        ),
      if (details.relatedTotal > details.related.length)
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  ObjectiveResourcesScreen(objectiveId: details.objective.id),
            ),
          ),
          child: const Text('See all videos for this objective'),
        ),
    ],
  );
}

class VideoMaterials extends StatefulWidget {
  const VideoMaterials({
    super.key,
    required this.videoId,
    required this.details,
  });
  final int videoId;
  final VideoDetails details;
  @override
  State<VideoMaterials> createState() => _VideoMaterialsState();
}

class _VideoMaterialsState extends State<VideoMaterials> {
  String? _opening;
  String? _error;
  Future<void> _open(VideoMaterial file) async {
    setState(() {
      _opening = '${file.kind}/${file.id}';
      _error = null;
    });
    try {
      await SessionScope.of(context).openVideoMaterial(widget.videoId, file);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not open this material.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _quiz() async {
    final link = widget.details.quizUrl;
    if (link == null) return;
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
    children: [
      const Text('Materials', style: AppTextStyles.title),
      const SizedBox(height: AppSpacing.md),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(_error!),
        ),
      if (widget.details.materials.isEmpty)
        const Text('No downloadable materials have been added yet.'),
      for (final file in widget.details.materials)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(file.name, style: AppTextStyles.label),
                Text(
                  '${file.label} · ${(file.size / 1024).ceil()} KB',
                  style: AppTextStyles.caption,
                ),
                TextButton.icon(
                  onPressed: _opening == null ? () => _open(file) : null,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    _opening == '${file.kind}/${file.id}'
                        ? 'Opening…'
                        : 'Open material',
                  ),
                ),
              ],
            ),
          ),
        ),
      if (widget.details.quizUrl != null)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Quiz', style: AppTextStyles.title),
              Text(
                'Opens ${widget.details.quizUrl!.host} in your browser. The website may ask you to sign in.',
              ),
              TextButton.icon(
                onPressed: _quiz,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open quiz'),
              ),
            ],
          ),
        ),
    ],
  );
}
