import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/member_session.dart';
import '../models/member_course.dart';
import '../models/objective_resources.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/curriculum_notes.dart';
import '../utils/formatters.dart';
import '../widgets/learning_progress.dart';
import '../widgets/objective_video_preview.dart';
import '../widgets/qaabil_app_bar.dart';
import 'login_screen.dart';
import 'objective_resources_screen.dart';
import 'past_papers_screen.dart';

/// Actual course content and saved progress.
class MemberCourseScreen extends StatefulWidget {
  const MemberCourseScreen({super.key, required this.courseId});
  final int courseId;
  @override
  State<MemberCourseScreen> createState() => _MemberCourseScreenState();
}

class _MemberCourseScreenState extends State<MemberCourseScreen> {
  Future<MemberCourse>? _course;
  int? _memberId;
  late final AppLifecycleListener _lifecycle;
  bool _returningFromQuiz = false;
  bool _launchingQuiz = false;
  bool _openingReport = false;
  Future<MemberCourse>? _refresh;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_returningFromQuiz) return;
        _returningFromQuiz = false;
        _refreshCourse();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (_course == null || _memberId != session.member?.id) {
      _memberId = session.member?.id;
      _returningFromQuiz = false;
      _refresh = null;
      _course = _load(session);
    }
  }

  Future<MemberCourse> _load(MemberSession session) => session.member == null
      ? session.api.publicCourse(widget.courseId)
      : session.course(widget.courseId);

  Future<void> _refreshCourse() async {
    if (_refresh != null) return;
    final session = SessionScope.of(context);
    final request = _refresh = _load(session);
    try {
      await request;
      if (mounted &&
          identical(_refresh, request) &&
          _memberId == session.member?.id) {
        setState(() {
          _course = request;
        });
      }
    } on ApiException catch (error) {
      if (mounted &&
          identical(_refresh, request) &&
          _memberId == session.member?.id) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (identical(_refresh, request)) _refresh = null;
    }
  }

  Future<void> _openQuiz(String path) async {
    if (_launchingQuiz) return;
    _launchingQuiz = true;
    try {
      final url = SessionScope.of(context).api.quizUrl(path);
      _returningFromQuiz = true;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const ApiException('Could not open the quiz in your browser.');
      }
    } catch (_) {
      _returningFromQuiz = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the quiz in your browser.'),
          ),
        );
      }
    } finally {
      _launchingQuiz = false;
    }
  }

  Future<void> _openReport() async {
    final session = SessionScope.of(context);
    if (session.member == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
      return;
    }
    if (_openingReport) return;
    setState(() => _openingReport = true);
    try {
      await session.openCourseReport(widget.courseId);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _openingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: MediaQuery.sizeOf(context).width >= 640
          ? const QaabilAppBar(height: 76, logoHeight: 44)
          : const QaabilAppBar(),
      body: FutureBuilder<MemberCourse>(
        key: ValueKey(_memberId),
        future: _course,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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
                          : 'Could not load this course.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _course = _load(session);
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final course = snapshot.data;
          if (course == null) return const SizedBox.shrink();
          return RefreshIndicator(
            onRefresh: _refreshCourse,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CourseHero(
                    course: course,
                    openingReport: _openingReport,
                    onOpenReport: _openReport,
                  ),
                  _CourseOutline(
                    key: ValueKey(_memberId),
                    course: course,
                    memberId: _memberId,
                    onOpenQuiz: _openQuiz,
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

const _courseAmber = Color(0xFFF59E0B);
const _accordionDuration = Duration(milliseconds: 320);

class _CourseHero extends StatelessWidget {
  const _CourseHero({
    required this.course,
    required this.openingReport,
    required this.onOpenReport,
  });

  final MemberCourse course;
  final bool openingReport;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final chapters = course.sections.expand((section) => section.chapters);
    final stats = [
      (course.sections.length, 'Section'),
      (chapters.length, 'Chapter'),
      (
        chapters.fold(0, (count, chapter) => count + chapter.objectives.length),
        'Learning Objective',
      ),
      if (course.videoCount case final count?) (count, 'Video'),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navy,
        gradient: RadialGradient(
          center: Alignment(-.45, -.15),
          radius: .65,
          colors: [Color(0xFF36486A), AppColors.navy],
        ),
      ),
      child: GridPaper(
        color: const Color(0x0AFFFFFF),
        interval: 56,
        divisions: 1,
        subdivisions: 1,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final tablet = width >= 640;
                final desktop = width >= 1024;
                final inset = desktop
                    ? 32.0
                    : tablet
                    ? 24.0
                    : 16.0;
                final vertical = desktop
                    ? 56.0
                    : tablet
                    ? 40.0
                    : 32.0;
                final breadcrumb = _breadcrumb(context);
                final actions = _actions(context, tablet: tablet);
                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CourseEyebrow('COURSE', onDark: true),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        course.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: AppTextStyles.serif,
                          fontSize: (width * .045).clamp(28.8, 60.0),
                          height: 1.1,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    if (course.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        course.description,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                );
                final counters = Wrap(
                  spacing: tablet ? 12 : 8,
                  runSpacing: 8,
                  children: [
                    for (final (count, label) in stats)
                      _CourseStat(count: count, label: label, tablet: tablet),
                  ],
                );
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: inset,
                    vertical: vertical,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (tablet)
                        Row(
                          children: [
                            Expanded(flex: 3, child: breadcrumb),
                            const SizedBox(width: 16),
                            Expanded(flex: 7, child: actions),
                          ],
                        )
                      else ...[
                        breadcrumb,
                        const SizedBox(height: 12),
                        actions,
                      ],
                      SizedBox(height: tablet ? 32 : 16),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: intro),
                            const SizedBox(width: 32),
                            Flexible(child: counters),
                          ],
                        )
                      else ...[
                        intro,
                        SizedBox(height: tablet ? 48 : 24),
                        counters,
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _breadcrumb(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      InkWell(
        onTap: () => Navigator.maybePop(context),
        child: Text(
          'Courses',
          style: AppTextStyles.caption.copyWith(color: Colors.white60),
        ),
      ),
      const Text('✦', style: TextStyle(color: _courseAmber, fontSize: 10)),
      Text(
        course.name,
        style: AppTextStyles.caption.copyWith(color: Colors.white70),
      ),
    ],
  );

  Widget _actions(BuildContext context, {required bool tablet}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course.notes.isNotEmpty) ...[
            Expanded(
              child: CurriculumNotes(
                kind: 'course',
                resourceId: course.id,
                notes: course.notes,
                accent: _courseAmber,
                tint: const Color(0x14FFFFFF),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: OutlinedButton.icon(
              style: _heroButtonStyle(),
              icon: const Icon(
                Icons.description_outlined,
                size: 14,
                color: _courseAmber,
              ),
              label: const Text('Past Papers'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PastPapersScreen(
                    initialCourseId: course.id,
                    onBrowseCourses: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: _heroButtonStyle(),
        icon: const Icon(
          Icons.download_outlined,
          size: 14,
          color: _courseAmber,
        ),
        label: Text(
          openingReport
              ? 'Preparing…'
              : tablet
              ? 'Download My Progress Report'
              : 'Progress Report',
        ),
        onPressed: openingReport ? null : onOpenReport,
      ),
    ],
  );
}

ButtonStyle _heroButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  backgroundColor: const Color(0x14FFFFFF),
  side: const BorderSide(color: Color(0x20FFFFFF)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  minimumSize: const Size(0, 38),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: AppTextStyles.label.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w800,
  ),
);

class _CourseStat extends StatelessWidget {
  const _CourseStat({
    required this.count,
    required this.label,
    required this.tablet,
  });

  final int count;
  final String label;
  final bool tablet;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minWidth: tablet ? 100 : 80),
    padding: EdgeInsets.symmetric(
      horizontal: tablet ? 20 : 16,
      vertical: tablet ? 14 : 12,
    ),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(tablet ? 16 : 12),
      border: Border.all(color: const Color(0x20FFFFFF)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: AppTextStyles.serif,
            fontSize: tablet ? 32 : 26,
            height: 1,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          (count == 1 ? label : '${label}s').toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.pill.copyWith(
            color: Colors.white60,
            fontSize: tablet ? 11 : 9.5,
          ),
        ),
      ],
    ),
  );
}

class _CourseEyebrow extends StatelessWidget {
  const _CourseEyebrow(this.label, {this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 3,
        decoration: BoxDecoration(
          color: _courseAmber,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: AppTextStyles.eyebrow.copyWith(
          color: onDark ? Colors.white70 : AppPalette.of(context).accent,
        ),
      ),
    ],
  );
}

ExpansibleController _courseController(bool expanded) {
  final controller = ExpansibleController();
  if (expanded) controller.expand();
  return controller;
}

typedef _CourseLocation = ({
  String label,
  String subtitle,
  int section,
  int? chapter,
  int? objective,
});

class _CourseOutline extends StatefulWidget {
  const _CourseOutline({
    super.key,
    required this.course,
    required this.memberId,
    required this.onOpenQuiz,
  });

  final MemberCourse course;
  final int? memberId;
  final ValueChanged<String> onOpenQuiz;

  @override
  State<_CourseOutline> createState() => _CourseOutlineState();
}

class _CourseOutlineState extends State<_CourseOutline> {
  final _sections = <int, ExpansibleController>{};
  final _chapters = <int, ExpansibleController>{};
  final _anchors = <(String, int), GlobalKey>{};

  GlobalKey _anchor(String kind, int id) =>
      _anchors.putIfAbsent((kind, id), GlobalKey.new);

  @override
  void dispose() {
    for (final controller in [..._sections.values, ..._chapters.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _jump() async {
    final locations = <_CourseLocation>[
      for (final section in widget.course.sections) ...[
        (
          label: section.name,
          subtitle: 'Section',
          section: section.id,
          chapter: null,
          objective: null,
        ),
        for (final chapter in section.chapters) ...[
          (
            label: chapter.name,
            subtitle: section.name,
            section: section.id,
            chapter: chapter.id,
            objective: null,
          ),
          for (final objective in chapter.objectives)
            (
              label: objective.name,
              subtitle: chapter.name,
              section: section.id,
              chapter: chapter.id,
              objective: objective.id,
            ),
        ],
      ],
    ];
    var query = '';
    final location = await showDialog<_CourseLocation>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final matches = locations.where((location) {
            if (query.isEmpty) return location.objective == null;
            return location.label.toLowerCase().contains(query) ||
                location.subtitle.toLowerCase().contains(query);
          }).toList();
          return AlertDialog(
            title: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search course content',
              ),
              onChanged: (value) =>
                  update(() => query = value.trim().toLowerCase()),
            ),
            content: SizedBox(
              width: 420,
              height: 300,
              child: matches.isEmpty
                  ? const Center(child: Text('No matches found.'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        return ListTile(
                          title: Text(match.label),
                          subtitle: Text(match.subtitle),
                          onTap: () => Navigator.pop(context, match),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
    if (location == null || !mounted) return;

    _sections[location.section]?.expand();
    if (location.chapter case final chapter?) _chapters[chapter]?.expand();
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;
    final target = location.objective != null
        ? _anchors[('objective', location.objective!)]
        : location.chapter != null
        ? _anchors[('chapter', location.chapter!)]
        : _anchors[('section', location.section)];
    final targetContext = target?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: _accordionDuration,
        alignment: .08,
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildSection(
    OutlineSection section, {
    required int index,
    required int firstChapterNumber,
    required bool wide,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _CourseAccordion(
      key: _anchor('section', section.id),
      controller: _sections.putIfAbsent(
        section.id,
        () => _courseController(index == 0),
      ),
      name: section.name,
      number: index + 1,
      count: wide ? pluralize(section.chapters.length, 'chapter') : null,
      isSection: true,
      footer: widget.memberId == null
          ? null
          : _CourseFooter(
              kind: 'section',
              resourceId: section.id,
              notes: section.notes,
              quizPath: section.quizPath,
              onOpenQuiz: widget.onOpenQuiz,
            ),
      body: Padding(
        padding: EdgeInsets.all(wide ? 20 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (section.chapters.isEmpty)
              const Text('No chapters have been added yet.'),
            for (final (position, chapter) in section.chapters.indexed)
              Padding(
                padding: EdgeInsets.only(top: position == 0 ? 0 : 12),
                child: _buildChapter(
                  chapter,
                  number: firstChapterNumber + position,
                  initiallyExpanded: index == 0 && position == 0,
                  wide: wide,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildChapter(
    OutlineChapter chapter, {
    required int number,
    required bool initiallyExpanded,
    required bool wide,
  }) => _CourseAccordion(
    key: _anchor('chapter', chapter.id),
    controller: _chapters.putIfAbsent(
      chapter.id,
      () => _courseController(initiallyExpanded),
    ),
    name: chapter.name,
    number: number,
    count: wide ? pluralize(chapter.objectives.length, 'objective') : null,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chapter.objectives.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No objectives have been added yet.'),
          ),
        for (final objective in chapter.objectives)
          _ObjectiveStep(
            key: _anchor('objective', objective.id),
            objective: objective,
            isMember: widget.memberId != null,
            onOpenQuiz: widget.onOpenQuiz,
          ),
        if (widget.memberId != null)
          _CourseFooter(
            kind: 'chapter',
            resourceId: chapter.id,
            notes: chapter.notes,
            quizPath: chapter.quizPath,
            onOpenQuiz: widget.onOpenQuiz,
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    var chapterNumber = 1;
    final firstChapterNumbers = <int>[];
    for (final section in course.sections) {
      firstChapterNumbers.add(chapterNumber);
      chapterNumber += section.chapters.length;
    }

    return CallbackShortcuts(
      bindings: {
        if (course.sections.isNotEmpty)
          const SingleActivator(LogicalKeyboardKey.slash): _jump,
      },
      child: Focus(
        autofocus: true,
        child: _buildOutline(context, firstChapterNumbers),
      ),
    );
  }

  Widget _buildOutline(BuildContext context, List<int> firstChapterNumbers) {
    final course = widget.course;
    final isMember = widget.memberId != null;
    return ColoredBox(
      color: AppPalette.of(context).background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.sizeOf(context).width >= 640 ? 56 : 40,
              24,
              48,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final title = Text.rich(
                  TextSpan(
                    text: 'Sections ',
                    children: [
                      TextSpan(
                        text: '& Chapters',
                        style: TextStyle(
                          fontFamily: AppTextStyles.serif,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.normal,
                          color: AppPalette.of(context).accent,
                          fontSize: 30,
                        ),
                      ),
                    ],
                  ),
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppPalette.of(context).textPrimary,
                    fontSize: 28,
                  ),
                );
                final jumpButton = OutlinedButton(
                  onPressed: course.sections.isEmpty ? null : _jump,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.of(context).textMuted,
                    backgroundColor: AppPalette.of(context).surface,
                    side: BorderSide(color: AppPalette.of(context).border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppTextStyles.label.copyWith(fontSize: 13),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 16),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text('Jump to section or chapter…'),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 10),
                        ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppPalette.of(context).elevated,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              child: Text('/'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CourseEyebrow('Course content'),
                    const SizedBox(height: 6),
                    if (wide)
                      Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 12),
                          jumpButton,
                        ],
                      )
                    else ...[
                      title,
                      const SizedBox(height: 10),
                      jumpButton,
                    ],
                    const SizedBox(height: 40),
                    if (course.sections.isEmpty)
                      const Text('No sections have been added yet.'),
                    for (final (index, section) in course.sections.indexed)
                      _buildSection(
                        section,
                        index: index,
                        firstChapterNumber: firstChapterNumbers[index],
                        wide: wide,
                      ),
                    if (isMember && course.progress != null) ...[
                      const SizedBox(height: 8),
                      AppCard(
                        child: LearningProgressView(progress: course.progress!),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseAccordion extends StatelessWidget {
  const _CourseAccordion({
    super.key,
    required this.controller,
    required this.name,
    required this.number,
    required this.body,
    this.count,
    this.footer,
    this.isSection = false,
  });

  final ExpansibleController controller;
  final String name;
  final int number;
  final Widget body;
  final Widget? footer;
  final String? count;
  final bool isSection;

  @override
  Widget build(BuildContext context) => Material(
    color: isSection
        ? AppPalette.of(context).background
        : AppPalette.of(context).surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: AppPalette.of(context).border),
      borderRadius: BorderRadius.circular(isSection ? 16 : 12),
    ),
    child: Expansible(
      controller: controller,
      maintainState: false,
      expansibleBuilder: (context, header, body, animation) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, body, ?footer],
      ),
      animationStyle: const AnimationStyle(
        duration: _accordionDuration,
        curve: Curves.easeInOut,
      ),
      headerBuilder: (context, animation) {
        final open = controller.isExpanded;
        final dark = isSection && open;
        final foreground = dark
            ? Colors.white
            : AppPalette.of(context).textPrimary;
        return Semantics(
          button: true,
          expanded: open,
          child: Ink(
            decoration: BoxDecoration(
              gradient: isSection
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? const [AppColors.navy, AppColors.navyDark]
                          : const [Color(0x121B3A6B), Color(0x081B3A6B)],
                    )
                  : null,
            ),
            child: InkWell(
              onTap: controller.toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white12 : const Color(0x121B3A6B),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontFamily: AppTextStyles.serif,
                          fontSize: 18,
                          color: dark
                              ? Colors.white
                              : AppPalette.of(context).accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: AppTextStyles.label.copyWith(color: foreground),
                      ),
                    ),
                    if (count case final count?) ...[
                      const SizedBox(width: 8),
                      Text(
                        count,
                        style: AppTextStyles.caption.copyWith(
                          color: dark
                              ? Colors.white70
                              : AppPalette.of(context).textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: Tween<double>(
                        begin: 0,
                        end: .5,
                      ).animate(animation),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: dark
                            ? Colors.white70
                            : AppPalette.of(context).textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      bodyBuilder: (context, animation) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.of(context).border)),
        ),
        child: body,
      ),
    ),
  );
}

class _ObjectiveStep extends StatelessWidget {
  const _ObjectiveStep({
    super.key,
    required this.objective,
    required this.isMember,
    required this.onOpenQuiz,
  });

  final OutlineObjective objective;
  final bool isMember;
  final ValueChanged<String> onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    final status = isMember ? objective.status : 'not_started';
    final statusColor = switch (status) {
      'mastery' => AppPalette.of(context).teal,
      'practice' => _courseAmber,
      'behind' => AppPalette.of(context).error,
      _ => AppPalette.of(context).textMuted,
    };
    void openResources() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isMember
            ? ObjectiveResourcesScreen(objectiveId: objective.id)
            : const LoginScreen(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppPalette.of(context).dark
                  ? const [Color(0xFF4B3522), Color(0xFF352A21)]
                  : const [Color(0xFFFFE2B5), Color(0xFFFFF0D9)],
            ),
            border: Border(
              top: BorderSide(color: AppPalette.of(context).border),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Semantics(
                  label: isMember ? objective.statusLabel : null,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .36),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppPalette.of(context).border),
                    ),
                    child: Icon(Icons.circle, size: 6, color: statusColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    objective.name,
                    style: AppTextStyles.label.copyWith(
                      color: AppPalette.of(context).textPrimary,
                    ),
                  ),
                ),
                if (isMember) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: _courseActionStyle(context),
                    onPressed: openResources,
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: const Text('All videos'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isMember)
          ObjectiveVideoPreview(
            objectiveId: objective.id,
            footer: (notes) => _footer(context, status, notes),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: _courseActionStyle(context),
                onPressed: openResources,
                icon: const Icon(Icons.play_lesson_outlined, size: 16),
                label: const Text('Login for videos & notes'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    String status,
    List<LessonNote> notes,
  ) => _CourseFooter(
    kind: 'objective',
    resourceId: objective.id,
    notes: notes,
    quizPath: objective.quizPath,
    onOpenQuiz: onOpenQuiz,
    progress: Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('PROGRESS', style: AppTextStyles.eyebrow.copyWith(fontSize: 10)),
        for (final (value, label, color) in [
          ('behind', 'Falling Behind', AppPalette.of(context).error),
          ('practice', 'Need More Practice', AppPalette.of(context).amberText),
          ('mastery', 'Mastery Reached', AppPalette.of(context).teal),
        ])
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == value ? color.withValues(alpha: .08) : null,
              border: Border.all(
                color: status == value
                    ? color.withValues(alpha: .30)
                    : AppPalette.of(context).border,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: status == value
                    ? color
                    : AppPalette.of(context).textMuted,
                fontSize: 10,
                fontWeight: status == value ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}

class _CourseFooter extends StatelessWidget {
  const _CourseFooter({
    required this.kind,
    required this.resourceId,
    required this.notes,
    required this.quizPath,
    required this.onOpenQuiz,
    this.progress,
  });

  final String kind;
  final int resourceId;
  final List<LessonNote> notes;
  final String? quizPath;
  final ValueChanged<String> onOpenQuiz;
  final Widget? progress;

  @override
  Widget build(BuildContext context) {
    final hasActions = notes.isNotEmpty || quizPath != null;
    if (!hasActions && progress == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: switch (kind) {
          'section' => const Color(0x051B3A6B),
          'chapter' => AppPalette.of(context).background,
          _ => AppPalette.of(context).surface,
        },
        border: Border(top: BorderSide(color: AppPalette.of(context).border)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: kind == 'section' ? 24 : 20,
          vertical: kind == 'section' ? 14 : 12,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 480;
            final actions = [
              if (notes.isNotEmpty)
                CurriculumNotes(
                  kind: kind,
                  resourceId: resourceId,
                  notes: notes,
                  accent: AppColors.navy,
                  tint: const Color(0x141B3A6B),
                  stacked: stacked,
                ),
              if (quizPath case final path?)
                FilledButton.icon(
                  onPressed: () => onOpenQuiz(path),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: AppTextStyles.label.copyWith(fontSize: 12),
                  ),
                  icon: Icon(
                    kind == 'section'
                        ? Icons.science_outlined
                        : Icons.fact_check_outlined,
                    size: 15,
                  ),
                  label: Text(switch (kind) {
                    'section' => 'Take Section Exam',
                    'chapter' => 'Take Chapter test',
                    _ => 'Take Quiz',
                  }),
                ),
            ];
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [?progress, ...actions],
              );
            }
            final actionGroup = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, action) in actions.indexed) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Flexible(
                    flex: index == 0 && notes.isNotEmpty ? 2 : 1,
                    child: action,
                  ),
                ],
              ],
            );
            if (progress == null) {
              return Align(
                alignment: Alignment.centerRight,
                child: actionGroup,
              );
            }
            if (!hasActions) return progress!;
            return Row(
              children: [
                Expanded(child: progress!),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .72,
                  ),
                  child: actionGroup,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

ButtonStyle _courseActionStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
      foregroundColor: AppPalette.of(context).accent,
      backgroundColor: AppPalette.of(context).surface,
      side: BorderSide(color: AppPalette.of(context).border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTextStyles.label.copyWith(fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 38),
    );
