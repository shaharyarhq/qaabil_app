import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/member_session.dart';
import '../models/member_course.dart';
import '../services/member_api.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_appearance.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'member_course_screen.dart';

class MemberCourseOverviewScreen extends StatefulWidget {
  const MemberCourseOverviewScreen({super.key, required this.courseId});

  final int courseId;

  @override
  State<MemberCourseOverviewScreen> createState() =>
      _MemberCourseOverviewScreenState();
}

class _MemberCourseOverviewScreenState
    extends State<MemberCourseOverviewScreen> {
  int? _memberId;
  Future<MemberCourse>? _course;
  Object? _reportRequest;
  bool get _openingReport => _reportRequest != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final memberId = session.member?.id;
    if (_memberId != memberId) {
      _memberId = memberId;
      _reportRequest = null;
      _course = memberId == null ? null : session.course(widget.courseId);
    }
  }

  Future<void> _reload() async {
    final session = SessionScope.of(context);
    if (session.member == null) return;
    final request = session.course(widget.courseId);
    setState(() {
      _course = request;
    });
    try {
      await request;
    } on ApiException {
      // The FutureBuilder displays the error and retry action.
    }
  }

  Future<void> _openContent() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberCourseScreen(courseId: widget.courseId),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openWebsite() async {
    final url = SessionScope.of(context).api.courseWebsiteUrl(widget.courseId);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Report launcher failures the same way as an unavailable browser.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the course website.')),
      );
    }
  }

  Future<void> _downloadReport() async {
    final session = SessionScope.of(context);
    final request = Object();
    setState(() => _reportRequest = request);
    try {
      await session.openCourseReport(widget.courseId);
    } catch (error) {
      if (mounted && identical(_reportRequest, request)) {
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
      if (mounted && identical(_reportRequest, request)) {
        setState(() => _reportRequest = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final palette = _OverviewPalette(brightness == Brightness.dark);
    return Theme(
      data: ThemeData(
        brightness: brightness,
        fontFamily: AppTextStyles.sans,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _indigo,
          brightness: brightness,
          surface: palette.surface,
        ),
      ),
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          toolbarHeight: 64,
          backgroundColor: palette.surface,
          scrolledUnderElevation: 0,
          actions: const [AppearanceMenu()],
        ),
        body: _memberId == null
            ? Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  child: const Text('Log in to view your course overview'),
                ),
              )
            : FutureBuilder<MemberCourse>(
                key: ValueKey(_memberId),
                future: _course,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              error is ApiException
                                  ? error.message
                                  : 'Could not load this course.',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: _reload,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final course = snapshot.data;
                  if (course == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _overview(context, course);
                },
              ),
      ),
    );
  }

  Widget _overview(BuildContext context, MemberCourse course) {
    final palette = _OverviewPalette.of(context);
    final chapters = course.sections.expand((section) => section.chapters);
    final progress = course.progress;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = math.max(24.0, (constraints.maxWidth - 1280) / 2 + 24);
        final infoColumns = constraints.maxWidth - 2 * inset >= 960 ? 5 : 1;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(inset, 36, inset, 36),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Text('My Courses', style: palette.caption),
                  ),
                  Icon(Icons.chevron_right, size: 15, color: palette.muted),
                  Text(course.name, style: palette.caption),
                  Icon(Icons.chevron_right, size: 15, color: palette.muted),
                  Text('View', style: palette.caption),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Semantics(
                    header: true,
                    child: Text(
                      'View ${course.name}',
                      style: palette.heading.copyWith(
                        fontSize: 28,
                        height: 1.25,
                      ),
                    ),
                  );
                  final actions = Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _openWebsite,
                        style: FilledButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.north_east, size: 16),
                        label: const Text('View Course on Website'),
                      ),
                      FilledButton.icon(
                        onPressed: _openingReport ? null : _downloadReport,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.report,
                          foregroundColor: palette.reportInk,
                        ),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: Text(
                          _openingReport ? 'Opening…' : 'Download Report',
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth >= 660 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 16) {
                    return Row(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        actions,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [title, actions],
                  );
                },
              ),
              const SizedBox(height: 30),
              _OverviewPanel(
                title: 'Info',
                child: _PanelGrid(
                  columns: infoColumns,
                  spacing: 24,
                  children: [
                    _CourseFact(
                      'Sections',
                      '${course.sections.length}',
                      Icons.grid_view_outlined,
                      color: _indigo,
                    ),
                    _CourseFact(
                      'Chapters',
                      '${chapters.length}',
                      Icons.description_outlined,
                      color: const Color(0xFF38BDF8),
                    ),
                    _CourseFact(
                      'Objectives',
                      '${chapters.expand((chapter) => chapter.objectives).length}',
                      Icons.check_circle_outline,
                      color: _mastery,
                    ),
                    _CourseFact(
                      'Created',
                      _dateLabel(course.createdAt),
                      Icons.schedule,
                    ),
                    _CourseFact(
                      'Last updated',
                      _dateLabel(course.updatedAt),
                      Icons.update,
                    ),
                  ],
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 24),
                _CourseProgress(progress: progress),
              ],
              const SizedBox(height: 24),
              _OverviewPanel(
                title: 'Course Structure',
                icon: Icons.subject_rounded,
                child: course.sections.isEmpty
                    ? Text('No sections yet.', style: palette.caption)
                    : Column(
                        children: [
                          for (final (index, section)
                              in course.sections.indexed)
                            ExpansionTile(
                              key: PageStorageKey(
                                'overview-section-${section.id}',
                              ),
                              initiallyExpanded: index == 0,
                              shape: palette.outline,
                              collapsedShape: palette.outline,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              leading: _StatusBadge(
                                '${index + 1}',
                                color: _indigo,
                              ),
                              title: Text(section.name, style: palette.label),
                              subtitle: Text(
                                pluralize(section.chapters.length, 'chapter'),
                                style: palette.caption,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                12,
                              ),
                              children: [
                                for (final (chapterIndex, chapter)
                                    in section.chapters.indexed)
                                  ExpansionTile(
                                    key: PageStorageKey(
                                      'overview-chapter-${chapter.id}',
                                    ),
                                    shape: palette.outline,
                                    collapsedShape: palette.outline,
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    leading: _StatusBadge(
                                      '${chapterIndex + 1}',
                                      color: palette.muted,
                                    ),
                                    title: Text(
                                      chapter.name,
                                      style: palette.label,
                                    ),
                                    subtitle: Text(
                                      pluralize(
                                        chapter.objectives.length,
                                        'objective',
                                      ),
                                      style: palette.caption,
                                    ),
                                    children: [
                                      for (final objective
                                          in chapter.objectives)
                                        ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                          leading: Icon(
                                            Icons.circle,
                                            size: 12,
                                            color: _statusColor(
                                              objective.status,
                                            ),
                                          ),
                                          title: Text(objective.name),
                                          subtitle: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _StatusBadge(
                                              objective.statusLabel,
                                              color: _statusColor(
                                                objective.status,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openContent,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Open course content'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _dateLabel(DateTime? date) =>
      date == null ? 'Unavailable' : timeAgo(date.toLocal());
}

const _indigo = Color(0xFF6965D9);

class _OverviewPalette {
  const _OverviewPalette(this.dark);

  factory _OverviewPalette.of(BuildContext context) =>
      _OverviewPalette(Theme.of(context).brightness == Brightness.dark);

  final bool dark;

  Color get background =>
      dark ? const Color(0xFF100D10) : const Color(0xFFFAFAFA);
  Color get header => dark ? const Color(0xFF201820) : const Color(0xFFF2F0F2);
  Color get surface => dark ? header : Colors.white;
  Color get border => dark ? const Color(0xFF352B34) : const Color(0xFFE5E1E5);
  Color get ink => dark ? Colors.white : const Color(0xFF171317);
  Color get muted => dark ? const Color(0xFFB4A8B2) : const Color(0xFF6B646B);
  Color get report => dark ? const Color(0xFF16A34A) : const Color(0xFF4ADE80);
  Color get reportInk => dark ? Colors.black : const Color(0xFF14532D);

  TextStyle get heading =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink);
  TextStyle get caption => TextStyle(fontSize: 13, color: muted);
  TextStyle get label =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink);
  RoundedRectangleBorder get outline => RoundedRectangleBorder(
    side: BorderSide(color: border),
    borderRadius: BorderRadius.circular(12),
  );
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = _OverviewPalette.of(context);
    return Material(
      color: palette.header,
      shape: palette.outline,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              spacing: 12,
              children: [
                if (icon != null) Icon(icon, size: 19, color: palette.muted),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 5,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: palette.heading),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: palette.caption),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Material(
            color: palette.surface,
            shape: palette.outline,
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ],
      ),
    );
  }
}

class _PanelGrid extends StatelessWidget {
  const _PanelGrid({
    required this.columns,
    required this.spacing,
    required this.children,
  });

  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _CourseFact extends StatelessWidget {
  const _CourseFact(this.label, this.value, this.icon, {this.color});

  final String label, value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = _OverviewPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(label, style: palette.label),
        if (color case final color?)
          _StatusBadge(value, color: color, icon: icon)
        else
          Row(
            spacing: 5,
            children: [
              Icon(icon, size: 15, color: palette.muted),
              Flexible(child: Text(value, style: palette.caption)),
            ],
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, {required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = _OverviewPalette.of(context);
    final ink = palette.dark
        ? Color.lerp(color, Colors.white, .33)!
        : Color.lerp(color, palette.ink, .6)!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 5 : 8,
        vertical: icon == null ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          if (icon != null) Icon(icon, color: ink, size: 18),
          Flexible(
            child: Text(
              label,
              style: palette.label.copyWith(color: ink, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

const _mastery = Color(0xFF10B981);
const _practice = Color(0xFFF59E0B);
const _behind = Color(0xFFEF4444);
const _notStarted = Color(0xFFE5E7EB);

Color _statusColor(String status) => switch (status) {
  'mastery' => _mastery,
  'practice' => _practice,
  'behind' => _behind,
  _ => _notStarted,
};

typedef _ProgressSlice = ({String label, int count, Color color});

String _legendLabel(String status) => switch (status) {
  'Mastery' => 'Mastery Reached',
  'Practice' => 'Need Practice',
  'Behind' => 'Falling Behind',
  _ => status,
};

class _CourseProgress extends StatefulWidget {
  const _CourseProgress({required this.progress});

  final LearningProgress progress;

  @override
  State<_CourseProgress> createState() => _CourseProgressState();
}

class _CourseProgressState extends State<_CourseProgress> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final palette = _OverviewPalette.of(context);
    final progress = widget.progress;
    final slices = [
      (label: 'Mastery', count: progress.mastery, color: _mastery),
      (label: 'Practice', count: progress.practice, color: _practice),
      (label: 'Behind', count: progress.behind, color: _behind),
      (label: 'Not Started', count: progress.notStarted, color: _notStarted),
    ];
    final selected = slices
        .where((slice) => slice.label == _selectedStatus)
        .firstOrNull;
    final summary = _OverviewPanel(
      title: 'My Progress',
      subtitle: '${progress.started} of ${progress.total} objectives marked',
      trailing: Text(
        '${progress.coveragePercent}%',
        style: palette.heading.copyWith(fontSize: 22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          if (progress.total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final slice in slices)
                      if (slice.count > 0)
                        Expanded(
                          flex: slice.count,
                          child: ColoredBox(
                            color: slice.label == 'Not Started'
                                ? palette.border
                                : slice.color,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) => _PanelGrid(
              columns:
                  constraints.maxWidth >= 485 &&
                      MediaQuery.textScalerOf(context).scale(13) < 18
                  ? 4
                  : 2,
              spacing: 12,
              children: [
                for (final slice in slices.reversed)
                  Container(
                    padding: EdgeInsets.all(
                      constraints.maxWidth >= 485 ? 22 : 12,
                    ),
                    decoration: ShapeDecoration(shape: palette.outline),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        _StatusBadge(slice.label, color: slice.color),
                        Text(
                          '${slice.count}',
                          style: palette.heading.copyWith(fontSize: 22),
                        ),
                        if (progress.total > 0)
                          Text(
                            '${(slice.count * 100 / progress.total).round()}% of total',
                            style: palette.caption,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final chart = _OverviewPanel(
      title: 'Learning Objectives — RAG',
      child: Center(
        child: Column(
          spacing: 14,
          children: [
            SizedBox.square(
              dimension: 216,
              child: CustomPaint(
                painter: _ProgressDonut(slices, selected?.label),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected == null
                            ? '${progress.coveragePercent}%'
                            : '${selected.count}',
                        style: palette.heading.copyWith(fontSize: 26),
                      ),
                      Text(
                        selected?.label ?? 'Marked',
                        style: palette.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (progress.total == 0)
              Text('No objectives yet.', style: palette.caption)
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: [
                  for (final slice in slices)
                    Semantics(
                      selected: selected == slice,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _selectedStatus = selected == slice
                              ? null
                              : slice.label;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: selected == slice
                              ? palette.ink
                              : palette.muted,
                          textStyle: palette.caption,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        icon: Icon(Icons.circle, color: slice.color, size: 12),
                        label: Text(_legendLabel(slice.label)),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [summary, chart],
    );
  }
}

class _ProgressDonut extends CustomPainter {
  const _ProgressDonut(this.slices, this.selectedStatus);

  final List<_ProgressSlice> slices;
  final String? selectedStatus;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = size.shortestSide;
    final center = size.center(Offset.zero);
    final ring = Rect.fromCircle(center: center, radius: diameter * .425);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = diameter * .15
      ..color = _notStarted;
    final total = slices.fold(0, (sum, slice) => sum + slice.count);
    if (total <= 0) {
      canvas.drawCircle(center, ring.width / 2, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = 2 * math.pi * slice.count / total;
      paint.color = selectedStatus == null || selectedStatus == slice.label
          ? slice.color
          : slice.color.withValues(alpha: .24);
      canvas.drawArc(ring, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_ProgressDonut oldDelegate) =>
      selectedStatus != oldDelegate.selectedStatus ||
      !listEquals(slices, oldDelegate.slices);
}
