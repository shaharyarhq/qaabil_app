import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/searchable_select.dart';

import '../auth/member_session.dart';
import '../models/objective_resources.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import '../widgets/objective_video_preview.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/search_field.dart';
import 'courses_screen.dart';
import 'login_screen.dart';
import 'member_course_screen.dart';

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
  int? _visibilityVersion;
  int? _openingNote;
  final _search = TextEditingController();
  String? _language, _focus;
  _VideoSort _sort = _VideoSort.newest;
  int? _creatorId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    _language = null;
    _focus = null;
    _sort = _VideoSort.newest;
    _creatorId = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (session.member?.id != _memberId ||
        _visibilityVersion != session.contentVisibilityVersion) {
      _memberId = session.member?.id;
      _visibilityVersion = session.contentVisibilityVersion;
      _clearFilters();
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

  Widget _videoDiscovery(List<LessonVideo> videos, int columns) {
    final languages =
        videos.map((video) => video.language).nonNulls.toSet().toList()..sort();
    final creators = Map.fromEntries(
      {
        for (final video in videos)
          if (video.creatorId != null && video.creator != null)
            video.creatorId!: video.creator!,
      }.entries.toList()..sort((a, b) => a.value.compareTo(b.value)),
    );
    final search = _search.text.trim().toLowerCase();
    final results =
        videos
            .where(
              (video) =>
                  (video.title.toLowerCase().contains(search) ||
                      (video.creator?.toLowerCase().contains(search) ??
                          false)) &&
                  (_language == null || video.language == _language) &&
                  (_focus == null || video.focus == _focus) &&
                  (_creatorId == null || video.creatorId == _creatorId),
            )
            .toList()
          ..sort(_sort.compare);

    final filters = [
      if (search.isNotEmpty)
        ('“${_search.text.trim()}”', () => setState(_search.clear)),
      if (_language case final language?)
        (language, () => setState(() => _language = null)),
      if (_focus case final focus?)
        (_focusLabels[focus] ?? focus, () => setState(() => _focus = null)),
      if (_creatorId case final id?)
        (creators[id] ?? 'Creator', () => setState(() => _creatorId = null)),
      if (_sort != _VideoSort.newest)
        (_sort.label, () => setState(() => _sort = _VideoSort.newest)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _ObjectiveSectionTitle('Videos')),
            Expanded(
              child: Text(
                'Showing ${pluralize(results.length, 'video')}',
                textAlign: TextAlign.end,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final small = width < 580;
              final filterWidth = small ? (width - 12) / 2 : 190.0;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: small ? width : 286,
                    child: SearchField(
                      controller: _search,
                      hint: 'Search by title or creator…',
                      onChanged: (_) => setState(() {}),
                      onClear: () => setState(_search.clear),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: _ObjectiveFilter<String>(
                      label: 'All languages',
                      icon: Icons.language,
                      value: languages.contains(_language) ? _language : null,
                      options: {
                        for (final language in languages) language: language,
                      },
                      onChanged: (value) => setState(() => _language = value),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: _ObjectiveFilter<String>(
                      label: 'All focus types',
                      icon: Icons.filter_list,
                      value: _focus,
                      options: _focusLabels,
                      onChanged: (value) => setState(() => _focus = value),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: _ObjectiveFilter<int>(
                      label: 'All creators',
                      icon: Icons.person_outline,
                      value: creators.containsKey(_creatorId)
                          ? _creatorId
                          : null,
                      options: creators,
                      onChanged: (value) => setState(() => _creatorId = value),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: _ObjectiveFilter<_VideoSort>(
                      label: 'Sort videos',
                      icon: Icons.sort_rounded,
                      value: _sort,
                      options: {
                        for (final sort in _VideoSort.values) sort: sort.label,
                      },
                      onChanged: (value) =>
                          setState(() => _sort = value ?? _VideoSort.newest),
                      showAll: false,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ACTIVE FILTERS',
                style: AppTextStyles.eyebrow.copyWith(
                  color: AppPalette.of(context).textMuted,
                  fontSize: 10,
                ),
              ),
              for (final (label, clear) in filters)
                InputChip(
                  label: Text(label, overflow: TextOverflow.ellipsis),
                  onDeleted: clear,
                  deleteButtonTooltipMessage: 'Remove $label filter',
                  backgroundColor: AppPalette.of(context).navyTint,
                  side: BorderSide(color: AppPalette.of(context).border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              TextButton(
                onPressed: () => setState(_clearFilters),
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              videos.isEmpty
                  ? 'No approved videos are available yet.'
                  : 'No videos match your search or filters.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 20.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final video in results)
                    SizedBox(
                      width: width,
                      child: ObjectiveVideoCard(video: video),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _notes(List<LessonNote> notes) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      const _ObjectiveSectionTitle('Objective notes'),
      if (notes.isEmpty)
        const Text('No notes have been added yet.', style: AppTextStyles.body),
      for (final note in notes)
        Material(
          color: AppPalette.of(context).surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppPalette.of(context).border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(
              Icons.description_outlined,
              color: AppPalette.of(context).accent,
            ),
            title: Text(note.name, style: AppTextStyles.label),
            subtitle: Text(
              _openingNote == note.id
                  ? 'Opening…'
                  : '${(note.size / 1024).ceil()} KB',
              style: AppTextStyles.caption,
            ),
            trailing: Icon(
              Icons.download_outlined,
              size: 20,
              color: AppPalette.of(context).accent,
            ),
            onTap: _openingNote == null ? () => _openNote(note) : null,
          ),
        ),
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
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final inset = math.max(24.0, (width - 1440) / 2 + 24);
                    return ListView(
                      children: [
                        _ObjectiveHero(resources: resources),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            inset,
                            width >= 640 ? 56 : 32,
                            inset,
                            48,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _videoDiscovery(
                                resources.videos,
                                width >= 1024
                                    ? 4
                                    : width >= 640
                                    ? 2
                                    : 1,
                              ),
                              const SizedBox(height: 32),
                              _notes(resources.notes),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

const _objectiveAmber = Color(0xFFF59E0B);
const _focusLabels = {
  'lesson_focused': 'Lesson Focused',
  'question_focused': 'Question Focused',
};

enum _VideoSort {
  newest('Newest first'),
  oldest('Oldest first'),
  ratingHigh('Highest rating first'),
  ratingLow('Lowest rating first');

  const _VideoSort(this.label);
  final String label;

  int compare(LessonVideo left, LessonVideo right) {
    final byDate = (left.submittedAt?.millisecondsSinceEpoch ?? 0).compareTo(
      right.submittedAt?.millisecondsSinceEpoch ?? 0,
    );
    final chronological = byDate == 0 ? left.id.compareTo(right.id) : byDate;
    final byRating = (left.averageRating ?? -1).compareTo(
      right.averageRating ?? -1,
    );
    return switch (this) {
      newest => -chronological,
      oldest => chronological,
      ratingHigh => byRating == 0 ? -chronological : -byRating,
      ratingLow => byRating == 0 ? -chronological : byRating,
    };
  }
}

class _ObjectiveFilter<T> extends StatelessWidget {
  const _ObjectiveFilter({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    this.showAll = true,
  });

  final String label;
  final IconData icon;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;
  final bool showAll;

  @override
  Widget build(BuildContext context) => SearchableSelect<T>(
    label: label,
    value: value,
    options: {if (showAll) null: label, ...options},
    onChanged: onChanged,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface,
        border: Border.all(color: AppPalette.of(context).border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, size: 15, color: AppPalette.of(context).textMuted),
          Expanded(
            child: Text(
              options[value] ?? label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontSize: 12),
            ),
          ),
          Icon(
            Icons.expand_more,
            size: 16,
            color: AppPalette.of(context).textMuted,
          ),
        ],
      ),
    ),
  );
}

class _ObjectiveSectionTitle extends StatelessWidget {
  const _ObjectiveSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Container(width: 16, height: 3, color: _objectiveAmber),
      Flexible(
        child: Semantics(
          header: true,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.serif,
              fontStyle: FontStyle.italic,
              fontSize: 30,
              color: AppPalette.of(context).textPrimary,
            ),
          ),
        ),
      ),
    ],
  );
}

class _ObjectiveHero extends StatelessWidget {
  const _ObjectiveHero({required this.resources});

  final ObjectiveResources resources;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final inset = math.max(24.0, (width - 1280) / 2 + 24);
      final subtitle = resources.chapterName;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          if (subtitle != null)
            Row(
              spacing: 8,
              children: [
                Container(width: 16, height: 3, color: _objectiveAmber),
                Flexible(
                  child: Text(
                    subtitle.toUpperCase(),
                    style: AppTextStyles.eyebrow.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          Semantics(
            header: true,
            child: Text(
              resources.name,
              style: TextStyle(
                fontFamily: AppTextStyles.serif,
                fontSize: (width * .05).clamp(36.0, 60.0),
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          if (resources.description.trim().isNotEmpty)
            Text(
              resources.description,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
        ],
      );
      final stat = Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          border: Border.all(color: const Color(0x20FFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              '${resources.videos.length}',
              style: const TextStyle(
                fontFamily: AppTextStyles.serif,
                color: Colors.white,
                fontSize: 36,
                height: 1,
              ),
            ),
            Text(
              resources.videos.length == 1 ? 'VIDEO' : 'VIDEOS',
              style: AppTextStyles.pill.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.navy,
          gradient: RadialGradient(
            center: Alignment(.64, -.38),
            radius: .7,
            colors: [Color(0xFF3E4C62), AppColors.navy],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset,
            vertical: width >= 640 ? 56 : 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const CoursesScreen()),
                    ),
                    child: Text(
                      'Courses',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  if (resources.courseName case final courseName?) ...[
                    const Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: _objectiveAmber,
                    ),
                    if (resources.courseId case final courseId?)
                      InkWell(
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                MemberCourseScreen(courseId: courseId),
                          ),
                        ),
                        child: Text(
                          courseName,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      )
                    else
                      Text(
                        courseName,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                  if (subtitle != null) ...[
                    const Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: _objectiveAmber,
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: _objectiveAmber,
                  ),
                  Text(
                    resources.name,
                    style: AppTextStyles.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: width >= 640 ? 36 : 24),
              if (width >= 1024)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 40,
                  children: [
                    Expanded(child: title),
                    stat,
                  ],
                )
              else ...[
                title,
                SizedBox(height: width >= 640 ? 56 : 24),
                stat,
              ],
            ],
          ),
        ),
      );
    },
  );
}
