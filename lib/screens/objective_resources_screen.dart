import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../services/member_api.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/qaabil_app_bar.dart';
import 'lesson_video_screen.dart';
import 'login_screen.dart';

class ObjectiveResourcesScreen extends StatefulWidget {
  const ObjectiveResourcesScreen({super.key, required this.objectiveId});
  final int objectiveId;
  @override
  State<ObjectiveResourcesScreen> createState() =>
      _ObjectiveResourcesScreenState();
}

class _ObjectiveResourcesScreenState extends State<ObjectiveResourcesScreen> {
  Future<ObjectiveResources>? _resources;
  int? _memberId;
  int? _openingNote;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (session.member?.id != _memberId) {
      _memberId = session.member?.id;
      _resources = _memberId == null
          ? null
          : session.resources(widget.objectiveId);
    }
  }

  Future<void> _openNote(LessonNote note) async {
    setState(() => _openingNote = note.id);
    try {
      await SessionScope.of(context).openNote(widget.objectiveId, note);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException
                  ? e.message
                  : 'Could not open these notes. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingNote = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: session.member == null
          ? Center(
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Log in to view learning resources'),
              ),
            )
          : FutureBuilder<ObjectiveResources>(
              future: _resources,
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
                                : 'Could not load resources.',
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _resources = session.resources(
                                widget.objectiveId,
                              );
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final resources = snapshot.data;
                if (resources == null) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.contentMaxWidth,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      children: [
                        Text(resources.name, style: AppTextStyles.heading),
                        const SizedBox(height: AppSpacing.xxl),
                        const Text('Videos', style: AppTextStyles.title),
                        const SizedBox(height: AppSpacing.md),
                        if (resources.videos.isEmpty)
                          const Text(
                            'No approved videos are available yet.',
                            style: AppTextStyles.body,
                          ),
                        for (final video in resources.videos)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg,
                            ),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (video.thumbnail != null)
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Image.network(
                                        video.thumbnail!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stack) =>
                                            const Center(
                                              child: Icon(
                                                Icons.ondemand_video,
                                                size: 48,
                                              ),
                                            ),
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(video.title, style: AppTextStyles.title),
                                  if (video.creator != null)
                                    Text(
                                      'By ${video.creator}',
                                      style: AppTextStyles.body,
                                    ),
                                  const SizedBox(height: AppSpacing.md),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LessonVideoScreen(
                                          videoId: video.id,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_circle_outline),
                                    label: const Text('Open video'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Objective notes',
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (resources.notes.isEmpty)
                          const Text(
                            'No notes have been added yet.',
                            style: AppTextStyles.body,
                          ),
                        for (final note in resources.notes)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(note.name, style: AppTextStyles.label),
                                  Text(
                                    '${(note.size / 1024).ceil()} KB',
                                    style: AppTextStyles.caption,
                                  ),
                                  TextButton.icon(
                                    onPressed: _openingNote == null
                                        ? () => _openNote(note)
                                        : null,
                                    icon: const Icon(
                                      Icons.description_outlined,
                                    ),
                                    label: Text(
                                      _openingNote == note.id
                                          ? 'Opening…'
                                          : 'Open notes',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
