import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/member_course.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/search_field.dart';
import 'member_area_screen.dart';
import 'member_course_overview_screen.dart';
import 'member_course_screen.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({
    super.key,
    required this.onBrowseCourses,
    this.active = true,
  });
  final VoidCallback onBrowseCourses;
  final bool active;
  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen> {
  final List<MemberCourse> _courses = [];
  final _search = TextEditingController();
  Timer? _debounce;
  MemberSession? _session;
  int? _memberId;
  int? _openingReport;
  int _requestVersion = 0;
  int _page = 0, _lastPage = 1;
  bool _loading = false, _retryFromStart = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = SessionScope.of(context);
    final id = _session!.member?.id;
    if (id != _memberId) {
      _memberId = id;
      _requestVersion++;
      _debounce?.cancel();
      _search.clear();
      _openingReport = null;
      _courses.clear();
      _page = 0;
      _loading = false;
      _error = null;
      if (id != null && widget.active) _load(reset: true);
    }
  }

  @override
  void didUpdateWidget(covariant MyLearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged() {
    _debounce?.cancel();
    setState(() {
      _requestVersion++;
      _courses.clear();
      _page = 0;
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (_memberId == null || (_loading && !reset)) return;
    _debounce?.cancel();
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _retryFromStart = reset;
      _error = null;
    });
    try {
      final result = await _session!.courses(
        page: reset ? 1 : _page + 1,
        search: _search.text,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        if (reset) _courses.clear();
        _courses.addAll(result.courses);
        _page = result.page;
        _lastPage = result.lastPage;
      });
    } on ApiException catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openCourse(int courseId, {bool overview = false}) async {
    final memberId = _memberId;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => overview
            ? MemberCourseOverviewScreen(courseId: courseId)
            : MemberCourseScreen(courseId: courseId),
      ),
    );
    if (mounted && _memberId == memberId) await _load(reset: true);
  }

  Future<void> _openReport(int courseId) async {
    final memberId = _memberId;
    setState(() => _openingReport = courseId);
    try {
      await _session!.openCourseReport(courseId);
    } catch (error) {
      if (mounted && _memberId == memberId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Could not open the report.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _memberId == memberId) {
        setState(() => _openingReport = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.member == null) {
      return MemberAreaScreen(
        title: 'My Learning',
        description: 'Your courses, progress and achievements, together.',
        icon: Icons.school_outlined,
        onBrowseCourses: widget.onBrowseCourses,
        features: const [
          (
            icon: Icons.menu_book_outlined,
            title: 'My courses',
            description: 'Return to the courses you are studying.',
          ),
          (
            icon: Icons.insights_outlined,
            title: 'Objective progress',
            description:
                'Track what needs practice and what you have mastered.',
          ),
          (
            icon: Icons.emoji_events_outlined,
            title: 'Badges and achievements',
            description: 'See recognition for your contributions and reviews.',
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: MediaQuery.sizeOf(context).width >= 640
          ? const QaabilAppBar(height: 76, logoHeight: 44)
          : const QaabilAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final inset = math.max(24.0, (constraints.maxWidth - 1440) / 2 + 24);
          final wide =
              constraints.maxWidth - 2 * inset >= 820 &&
              MediaQuery.textScalerOf(context).scale(14) <= 19;
          return RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              key: const PageStorageKey('member-learning'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(inset, 32, inset, 32),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'My Learning',
                    style: TextStyle(
                      fontFamily: AppTextStyles.serif,
                      fontSize: wide ? 50 : 40,
                      height: 1.1,
                      color: AppPalette.of(context).textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Material(
                  color: AppPalette.of(context).surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppPalette.of(context).border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            const Text(
                              'My Courses',
                              style: AppTextStyles.title,
                            ),
                            SizedBox(
                              width: wide ? 300 : double.infinity,
                              child: SearchField(
                                controller: _search,
                                hint: 'Search my courses…',
                                onChanged: (_) => _searchChanged(),
                                onClear: () {
                                  _search.clear();
                                  _searchChanged();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_loading && _courses.isEmpty)
                        const LinearProgressIndicator(),
                      if (_error case final error?)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(error, style: AppTextStyles.body),
                              TextButton(
                                onPressed: () => _load(reset: _retryFromStart),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      if (!_loading && _error == null && _courses.isEmpty)
                        _emptyState(),
                      if (wide && _courses.isNotEmpty)
                        ColoredBox(
                          color: AppPalette.of(context).elevated,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              spacing: 20,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Course',
                                    style: AppTextStyles.label,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'My Progress',
                                    style: AppTextStyles.label,
                                  ),
                                ),
                                SizedBox(width: 300),
                              ],
                            ),
                          ),
                        ),
                      for (final course in _courses) ...[
                        Divider(
                          height: 1,
                          color: AppPalette.of(context).border,
                        ),
                        _LearningCourseRow(
                          course: course,
                          wide: wide,
                          onOpen: () => _openCourse(course.id),
                          onOverview: () =>
                              _openCourse(course.id, overview: true),
                          onReport: _openingReport == null
                              ? () => _openReport(course.id)
                              : null,
                          openingReport: _openingReport == course.id,
                        ),
                      ],
                      if (_courses.isNotEmpty && _page < _lastPage)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: TextButton(
                              onPressed: _loading ? null : () => _load(),
                              child: Text(
                                _loading ? 'Loading…' : 'Load more courses',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    final searching = _search.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        spacing: 8,
        children: [
          Icon(
            searching ? Icons.search_off_rounded : Icons.menu_book_outlined,
            color: AppPalette.of(context).accent,
            size: 28,
          ),
          Text(
            searching
                ? 'No courses match your search'
                : 'No learning progress yet',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          if (!searching) ...[
            const Text(
              'Start a course on Qaabil to see your saved objective progress here.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: widget.onBrowseCourses,
              child: const Text('Browse courses'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LearningCourseRow extends StatelessWidget {
  const _LearningCourseRow({
    required this.course,
    required this.wide,
    required this.onOpen,
    required this.onOverview,
    required this.onReport,
    required this.openingReport,
  });

  final MemberCourse course;
  final bool wide;
  final VoidCallback onOpen;
  final VoidCallback onOverview;
  final VoidCallback? onReport;
  final bool openingReport;

  @override
  Widget build(BuildContext context) {
    final progress = course.progress!;
    final coverage = progress.coveragePercent;
    final progressColor = switch (coverage) {
      <= 0 => const Color(0xFFF43F5E),
      <= 50 => const Color(0xFFFB923C),
      _ => const Color(0xFF22C55E),
    };
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(course.name, style: AppTextStyles.title),
        if (course.qualification case final qualification?)
          Text(qualification, style: AppTextStyles.caption),
      ],
    );
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        LinearProgressIndicator(
          value: (coverage / 100).clamp(0, 1),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: progressColor,
          backgroundColor: progressColor.withValues(alpha: .15),
          semanticsLabel: 'Objectives started',
          semanticsValue: '$coverage%',
        ),
        Text('$coverage% objectives started', style: AppTextStyles.label),
        Text(
          '${progress.started} of ${progress.total} objectives · ${progress.masteryPercent}% mastered',
          style: AppTextStyles.caption,
        ),
      ],
    );
    final actions = Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: wide ? WrapAlignment.end : WrapAlignment.start,
      children: [
        TextButton(onPressed: onOverview, child: const Text('Overview')),
        TextButton(onPressed: onOpen, child: const Text('Open course')),
        TextButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.download_outlined, size: 17),
          label: Text(openingReport ? 'Opening…' : 'Report'),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: wide
          ? Row(
              spacing: 20,
              children: [
                Expanded(child: name),
                Expanded(child: summary),
                SizedBox(width: 300, child: actions),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [name, summary, actions],
            ),
    );
  }
}
