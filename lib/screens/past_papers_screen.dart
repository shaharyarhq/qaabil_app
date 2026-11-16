import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/searchable_select.dart';

import '../auth/member_session.dart';
import '../models/past_papers.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import 'login_screen.dart';

class PastPapersScreen extends StatefulWidget {
  const PastPapersScreen({
    super.key,
    required this.onBrowseCourses,
    this.active = true,
    this.initialCourseId,
  });
  final VoidCallback onBrowseCourses;
  final bool active;
  final int? initialCourseId;
  @override
  State<PastPapersScreen> createState() => _PastPapersScreenState();
}

class _PastPapersScreenState extends State<PastPapersScreen> {
  final _search = TextEditingController();
  final _papers = <PastPaper>[];
  MemberSession? _session;
  int? _memberId, _course, _year;
  String? _sitting, _error;
  List<PaperCourse> _courses = [];
  List<int> _years = [];
  List<String> _sittings = [];
  int _version = 0, _page = 0, _lastPage = 1, _total = 0;
  bool _loading = false, _loaded = false;
  Timer? _debounce;
  String? _opening;
  _PaperGrouping _grouping = _PaperGrouping.year;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = SessionScope.of(context);
    if (_session!.member?.id != _memberId) {
      _memberId = _session!.member?.id;
      _version++;
      _debounce?.cancel();
      _papers.clear();
      _courses = [];
      _years = [];
      _sittings = [];
      _course = widget.initialCourseId;
      _year = null;
      _sitting = null;
      _search.clear();
      _page = 0;
      _total = 0;
      _lastPage = 1;
      _error = null;
      _loading = false;
      _loaded = false;
      _opening = null;
      _grouping = _PaperGrouping.year;
    }
    if (widget.active && _memberId != null && !_loaded) _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant PastPapersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _memberId != null && !_loaded) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_memberId == null || (_loading && !reset)) return;
    _debounce?.cancel();
    final version = ++_version;
    setState(() {
      _loading = true;
      _loaded = true;
      _error = null;
      if (reset) {
        _papers.clear();
        _page = 0;
        _total = 0;
      }
    });
    try {
      final result = await _session!.pastPapers(
        search: _search.text,
        course: _course,
        year: _year,
        sitting: _sitting,
        page: reset ? 1 : _page + 1,
      );
      if (!mounted || version != _version) return;
      setState(() {
        _papers.addAll(result.papers);
        _page = result.page;
        _lastPage = result.lastPage;
        _total = result.total;
        _courses = result.courses;
        _years = result.years;
        _sittings = result.sittings;
      });
    } on ApiException catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    // Invalidate the previous query immediately, including during debounce.
    _version++;
    setState(() {
      _loading = true;
      _papers.clear();
      _error = null;
      _total = 0;
    });
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
  }

  void _resetFilters() {
    _search.clear();
    _course = null;
    _year = null;
    _sitting = null;
    _load(reset: true);
  }

  Future<void> _openReport() async {
    final courses = _courses;
    final session = _session!;
    final memberId = _memberId;
    var selected = courses.any((course) => course.id == _course)
        ? _course
        : courses.length == 1
        ? courses.single.id
        : null;
    var opening = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !opening,
          child: AlertDialog(
            scrollable: true,
            title: const Text('Past Papers progress report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose a course to export your marks and grade breakdown.',
                ),
                const SizedBox(height: AppSpacing.md),
                SearchableSelectField<int>(
                  label: 'Course',
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Course'),
                  options: {
                    for (final course in courses) course.id: course.name,
                  },
                  onChanged: opening
                      ? null
                      : (value) => update(() {
                          selected = value;
                          error = null;
                        }),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: opening ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null || opening
                    ? null
                    : () async {
                        if (session.member?.id != memberId) {
                          update(
                            () => error = 'Sign in again to open your report.',
                          );
                          return;
                        }
                        update(() {
                          opening = true;
                          error = null;
                        });
                        try {
                          await session.openPaperReport(selected!);
                          if (context.mounted) Navigator.of(context).pop();
                        } on ApiException catch (failure) {
                          if (context.mounted) {
                            update(() {
                              opening = false;
                              error = failure.message;
                            });
                          }
                        }
                      },
                child: Text(opening ? 'Opening…' : 'Open PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editScore(PastPaper paper) async {
    final maximum = paper.totalMarks;
    if (maximum == null) return;
    final memberId = _memberId;
    final session = _session!;
    final form = GlobalKey<FormState>();
    var input = paper.myScore?.toString() ?? '';
    var saving = false;
    String? error;

    final saved = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Your marks'),
            content: Form(
              key: form,
              child: TextFormField(
                initialValue: input,
                autofocus: true,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Marks out of $maximum',
                  errorText: error,
                  errorMaxLines: 3,
                ),
                onChanged: (value) {
                  input = value;
                  if (error != null) update(() => error = null);
                },
                validator: (value) {
                  final score = int.tryParse(value?.trim() ?? '', radix: 10);
                  if (score == null || score < 0 || score > maximum) {
                    return 'Enter a whole number from 0 to $maximum.';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final score = await session.savePaperScore(
                            paper.id,
                            int.parse(input.trim(), radix: 10),
                          );
                          if (context.mounted) Navigator.of(context).pop(score);
                        } on ApiException catch (failure) {
                          if (context.mounted) {
                            update(() {
                              saving = false;
                              error = failure.message;
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save marks'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || saved == null || session.member?.id != memberId) return;
    final index = _papers.indexWhere((item) => item.id == paper.id);
    if (index >= 0) {
      setState(() => _papers[index] = _papers[index].withScore(saved));
    }
  }

  Future<void> _open(PastPaper paper, PaperDocument file) async {
    final key = '${paper.id}/${file.kind}';
    final memberId = _memberId;
    setState(() => _opening = key);
    try {
      await _session!.openPaperDocument(paper.id, file);
    } catch (error) {
      if (mounted && _memberId == memberId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Could not open this paper. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _memberId == memberId) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = SessionScope.of(context).member;
    final filtered =
        _search.text.isNotEmpty ||
        _course != null ||
        _year != null ||
        _sitting != null;
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              key: const PageStorageKey('past-papers'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: math.max(
                  20,
                  (MediaQuery.sizeOf(context).width - 1200) / 2,
                ),
                vertical: 24,
              ),
              children: [
                if (member == null)
                  const SectionHeader(
                    eyebrow: 'EXAM PRACTICE',
                    title: 'Past Papers',
                    accent: '',
                    subtitle: 'Find your paper. Get ready for your next exam.',
                  ),
                if (member == null) const SizedBox(height: AppSpacing.xl),
                if (member == null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.assignment_rounded,
                          color: AppPalette.of(context).violet,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Your next practice session starts here',
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Log in to browse papers and open question papers, marking schemes and examiner reports.',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          child: const Text('Login to your account'),
                        ),
                        TextButton(
                          onPressed: widget.onBrowseCourses,
                          child: const Text('Browse courses'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Past Papers  ›  List',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      const Text('Past Papers', style: AppTextStyles.heading),
                      if (_courses.isNotEmpty)
                        FilledButton.icon(
                          onPressed: _openReport,
                          style: _downloadStyle(context, 'question_paper'),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Download my Past Paper Report'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: palette.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Filters',
                                    style: AppTextStyles.title,
                                  ),
                                  TextButton(
                                    onPressed: filtered ? _resetFilters : null,
                                    child: const Text('Reset'),
                                  ),
                                ],
                              ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 700
                                      ? 3
                                      : constraints.maxWidth >= 500
                                      ? 2
                                      : 1;
                                  final width =
                                      (constraints.maxWidth -
                                          (columns - 1) * 12) /
                                      columns;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: width,
                                        child: _PaperFilter(
                                          label: 'Paper Name',
                                          child: SearchField(
                                            controller: _search,
                                            hint: 'Search paper name…',
                                            onChanged: _searchChanged,
                                            onClear: () {
                                              _search.clear();
                                              _searchChanged('');
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: _PaperFilter(
                                          label: 'Course',
                                          child: SearchableSelectField<int>(
                                            label: 'Course',
                                            value:
                                                _courses.any(
                                                  (course) =>
                                                      course.id == _course,
                                                )
                                                ? _course
                                                : null,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                            ),
                                            options: {
                                              null: 'All courses',
                                              for (final course in _courses)
                                                course.id: course.name,
                                            },
                                            onChanged: (value) {
                                              _course = value;
                                              _load(reset: true);
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: _PaperFilter(
                                          label: 'Year',
                                          child: SearchableSelectField<int>(
                                            label: 'Year',
                                            value: _years.contains(_year)
                                                ? _year
                                                : null,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                            ),
                                            options: {
                                              null: 'All years',
                                              for (final year in _years)
                                                year: '$year',
                                            },
                                            onChanged: (value) {
                                              _year = value;
                                              _load(reset: true);
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: width,
                                        child: _PaperFilter(
                                          label: 'Sitting',
                                          child: SearchableSelectField<String>(
                                            label: 'Sitting',
                                            value: _sittings.contains(_sitting)
                                                ? _sitting
                                                : null,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                            ),
                                            options: {
                                              null: 'All sittings',
                                              for (final sitting in _sittings)
                                                sitting: sitting,
                                            },
                                            onChanged: (value) {
                                              _sitting = value;
                                              _load(reset: true);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: palette.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 10,
                                children: [
                                  const Text(
                                    'Group by',
                                    style: AppTextStyles.caption,
                                  ),
                                  SearchableSelect<_PaperGrouping>(
                                    label: 'Group by',
                                    value: _grouping,
                                    options: {
                                      for (final group in _PaperGrouping.values)
                                        group: group.label,
                                    },
                                    onChanged: (value) =>
                                        setState(() => _grouping = value!),
                                    child: SizedBox(
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Text(_grouping.label),
                                          const Icon(Icons.arrow_drop_down),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _loading && _papers.isEmpty
                                    ? 'Finding papers…'
                                    : '$_total ${_total == 1 ? 'paper' : 'papers'} found',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        ..._paperGroups(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_error != null)
                    AppCard(
                      child: Column(
                        children: [
                          Text(_error!, style: AppTextStyles.body),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => _load(reset: _papers.isEmpty),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  if (!_loading && _error == null && _papers.isEmpty)
                    AppCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.find_in_page_rounded,
                            size: 46,
                            color: AppPalette.of(context).violet,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            filtered
                                ? 'No matching papers'
                                : 'No past papers yet',
                            style: AppTextStyles.title,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            filtered ? 'Try another course, year or sitting.' : 'Papers will appear here when they are added to Qaabil.',
                            style: AppTextStyles.body,
                          ),
                          if (filtered)
                            TextButton(
                              onPressed: _resetFilters,
                              child: const Text('Show all papers'),
                            ),
                        ],
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_loading && _error == null && _page < _lastPage)
                    OutlinedButton(
                      onPressed: () => _load(),
                      child: const Text('Load more papers'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _paperGroups(BuildContext context) {
    final groups = <({Object id, String label}), List<PastPaper>>{};
    for (final paper in _papers) {
      final key = _grouping.keyFor(paper);
      groups.putIfAbsent(key, () => []).add(paper);
    }
    final keys = groups.keys.toList();
    if (_grouping == _PaperGrouping.course ||
        _grouping == _PaperGrouping.sitting) {
      keys.sort(
        (left, right) =>
            left.label.toLowerCase().compareTo(right.label.toLowerCase()),
      );
    }
    final palette = AppPalette.of(context);
    return [
      for (final key in keys)
        if (_grouping == _PaperGrouping.none)
          _paperGrid(groups[key]!)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, color: palette.border),
              ExpansionTile(
                key: PageStorageKey(('past-papers', _grouping, key)),
                initiallyExpanded: true,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  '${_grouping.label}: ${key.label}',
                  style: AppTextStyles.label,
                ),
                backgroundColor: palette.surface,
                collapsedBackgroundColor: palette.elevated,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                children: [
                  ColoredBox(
                    color: palette.surface,
                    child: _paperGrid(groups[key]!),
                  ),
                ],
              ),
            ],
          ),
    ];
  }

  Widget _paperGrid(List<PastPaper> papers) => Padding(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final paper in papers)
              SizedBox(
                width: width,
                child: _PaperCard(
                  paper: paper,
                  opening: _opening,
                  onOpen: (file) => _open(paper, file),
                  onEditScore: () => _editScore(paper),
                ),
              ),
          ],
        );
      },
    ),
  );
}

enum _PaperGrouping {
  none('None'),
  year('Year'),
  course('Course'),
  sitting('Sitting');

  const _PaperGrouping(this.label);
  final String label;

  ({Object id, String label}) keyFor(PastPaper paper) => switch (this) {
    none => (id: '', label: ''),
    year => (id: paper.year, label: '${paper.year}'),
    course => (id: paper.course.id, label: paper.course.name),
    sitting => (
      id: paper.sitting,
      label: paper.sitting.isEmpty ? 'Unspecified' : paper.sitting,
    ),
  };
}

class _PaperFilter extends StatelessWidget {
  const _PaperFilter({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Text(label, style: AppTextStyles.label),
      child,
    ],
  );
}

ButtonStyle _downloadStyle(BuildContext context, String kind) {
  final dark = AppPalette.of(context).dark;
  final (background, foreground) = switch (kind) {
    'marking_scheme' => (
      dark ? const Color(0xFF22C55E) : const Color(0xFF4ADE80),
      const Color(0xFF09361A),
    ),
    'examiners_report' => (
      dark ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24),
      const Color(0xFF482700),
    ),
    _ => (
      dark ? const Color(0xFF7470DB) : const Color(0xFF605ACC),
      Colors.white,
    ),
  };
  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    minimumSize: const Size(0, 36),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    textStyle: AppTextStyles.label,
  );
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.paper,
    required this.opening,
    required this.onOpen,
    required this.onEditScore,
  });
  final PastPaper paper;
  final String? opening;
  final ValueChanged<PaperDocument> onOpen;
  final VoidCallback onEditScore;
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                spacing: 7,
                children: [
                  if (paper.details.isNotEmpty)
                    Text(
                      paper.details,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  Text(
                    paper.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title,
                  ),
                  Text(
                    paper.course.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  Text('${paper.year}', style: AppTextStyles.caption),
                  if (paper.sitting.isNotEmpty)
                    Text(paper.sitting, style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  OutlinedButton(
                    onPressed: paper.totalMarks == null ? null : onEditScore,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      textStyle: AppTextStyles.label,
                    ),
                    child: Text(
                      paper.totalMarks == null
                          ? 'Your Marks · No max'
                          : paper.myScore == null
                          ? 'Add marks'
                          : 'Your marks: ${paper.myScore} / ${paper.totalMarks}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            if (paper.documents.isEmpty)
              const Text(
                'Documents are not available for this paper yet.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            for (final file in paper.documents)
              FilledButton.icon(
                style: _downloadStyle(context, file.kind),
                onPressed: opening == null ? () => onOpen(file) : null,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: Text(
                  opening == '${paper.id}/${file.kind}'
                      ? 'Opening…'
                      : file.label,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
