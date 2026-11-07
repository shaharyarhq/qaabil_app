import 'dart:async';

import 'package:flutter/material.dart';

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
  });
  final VoidCallback onBrowseCourses;
  final bool active;
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
      _course = null;
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
    return Scaffold(
      appBar: const QaabilAppBar(),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              key: const PageStorageKey('past-papers'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                const SectionHeader(
                  eyebrow: 'EXAM PRACTICE',
                  title: 'Past Papers',
                  accent: '',
                  subtitle: 'Find your paper. Get ready for your next exam.',
                ),
                const SizedBox(height: AppSpacing.xl),
                if (member == null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.assignment_rounded,
                          color: AppColors.violet,
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
                  SearchField(
                    controller: _search,
                    hint: 'Search paper name…',
                    onChanged: _searchChanged,
                    onClear: () {
                      _search.clear();
                      _searchChanged('');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    key: ValueKey('paper-course-$_course-${_courses.length}'),
                    initialValue: _courses.any((c) => c.id == _course)
                        ? _course
                        : null,
                    hint: const Text('All courses'),
                    decoration: const InputDecoration(labelText: 'Course'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('All courses'),
                      ),
                      for (final course in _courses)
                        DropdownMenuItem(
                          value: course.id,
                          child: Text(
                            course.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      _course = value;
                      _load(reset: true);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('paper-year-$_year-${_years.length}'),
                          initialValue: _years.contains(_year) ? _year : null,
                          hint: const Text('All years'),
                          decoration: const InputDecoration(labelText: 'Year'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('All years'),
                            ),
                            for (final year in _years)
                              DropdownMenuItem(
                                value: year,
                                child: Text('$year'),
                              ),
                          ],
                          onChanged: (value) {
                            _year = value;
                            _load(reset: true);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'paper-sitting-$_sitting-${_sittings.length}',
                          ),
                          initialValue: _sittings.contains(_sitting)
                              ? _sitting
                              : null,
                          hint: const Text(
                            'All sittings',
                            overflow: TextOverflow.ellipsis,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Sitting',
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All sittings',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            for (final sitting in _sittings)
                              DropdownMenuItem(
                                value: sitting,
                                child: Text(
                                  sitting,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            _sitting = value;
                            _load(reset: true);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _loading && _papers.isEmpty
                            ? 'Finding papers…'
                            : '$_total ${_total == 1 ? 'paper' : 'papers'} found',
                        style: AppTextStyles.caption,
                      ),
                      if (filtered)
                        TextButton(
                          onPressed: _resetFilters,
                          child: const Text('Clear filters'),
                        ),
                    ],
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
                          const Icon(
                            Icons.find_in_page_rounded,
                            size: 46,
                            color: AppColors.violet,
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
                  for (final paper in _papers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _PaperCard(
                        paper: paper,
                        opening: _opening,
                        onOpen: (file) => _open(paper, file),
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
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.paper,
    required this.opening,
    required this.onOpen,
  });
  final PastPaper paper;
  final String? opening;
  final ValueChanged<PaperDocument> onOpen;
  @override
  Widget build(BuildContext context) {
    final (accent, tint) = AppColors
        .learningAccents[(paper.id + 1) % AppColors.learningAccents.length];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.assignment_rounded, color: accent, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.course.name, style: AppTextStyles.caption),
                    Text(paper.name, style: AppTextStyles.cardTitle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${paper.year}'), backgroundColor: tint),
              if (paper.sitting.isNotEmpty)
                Chip(label: Text(paper.sitting), backgroundColor: tint),
              if (paper.totalMarks != null)
                Chip(
                  label: Text('${paper.totalMarks} marks'),
                  backgroundColor: tint,
                ),
            ],
          ),
          if (paper.details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(paper.details, style: AppTextStyles.body),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (paper.documents.isEmpty)
            const Text(
              'Documents are not available for this paper yet.',
              style: AppTextStyles.body,
            ),
          for (final file in paper.documents)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: accent,
                  backgroundColor: tint,
                  side: BorderSide(
                    color: accent.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                onPressed: opening != null ? null : () => onOpen(file),
                icon: opening == '${paper.id}/${file.kind}'
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : const Icon(Icons.file_open_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opening == '${paper.id}/${file.kind}'
                            ? 'Opening…'
                            : file.label,
                      ),
                      Text(
                        '${file.name.split('.').last.toUpperCase()} · ${(file.size / 1024).ceil()} KB',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
