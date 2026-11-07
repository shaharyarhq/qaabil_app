import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/catalogue_course.dart';
import '../models/course_sort.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/course_card.dart';
import '../widgets/filter_pill.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/sort_button.dart';
import 'member_course_screen.dart';

/// The public catalogue uses the same Laravel course records as the website.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _searchController = TextEditingController();
  final List<CatalogueCourse> _courses = [];
  List<CatalogueQualification> _qualifications = [];
  MemberApi? _api;
  Timer? _debounce;
  int? _qualification;
  CourseSort _sort = CourseSort.newest;
  int _version = 0, _page = 0, _lastPage = 1, _total = 0, _catalogueTotal = 0;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = SessionScope.of(context).api;
    if (_api != api) {
      _api = api;
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _queryChanged({bool debounce = false}) {
    _debounce?.cancel();
    // Invalidate older responses immediately, including during the debounce.
    _version++;
    setState(() {
      _courses.clear();
      _page = 0;
      _total = 0;
      _loading = true;
      _error = null;
    });
    if (debounce) {
      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => _load(reset: true),
      );
    } else {
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    _debounce?.cancel();
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _courses.clear();
        _page = 0;
      }
    });
    try {
      final result = await _api!.catalogue(
        search: _searchController.text,
        qualification: _qualification,
        sort: _sort.name,
        page: reset ? 1 : _page + 1,
      );
      if (!mounted || version != _version) return;
      setState(() {
        _courses.addAll(result.courses);
        _qualifications = result.qualifications;
        _page = result.page;
        _lastPage = result.lastPage;
        _total = result.total;
        _catalogueTotal = result.catalogueTotal;
      });
    } on ApiException catch (e) {
      if (mounted && version == _version) setState(() => _error = e.message);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    _qualification = null;
    _queryChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const QaabilAppBar(),
    body: GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.gridMaxWidth),
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                const SectionHeader(
                  eyebrow: 'All courses',
                  title: 'Start learning ',
                  accent: 'today',
                  sparkle: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                SearchField(
                  controller: _searchController,
                  onChanged: (_) => _queryChanged(debounce: true),
                  onClear: () {
                    _searchController.clear();
                    _queryChanged();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterPill(
                        label: 'All',
                        count: _catalogueTotal,
                        selected: _qualification == null,
                        onTap: () {
                          _qualification = null;
                          _queryChanged();
                        },
                      ),
                      for (final q in _qualifications) ...[
                        const SizedBox(width: AppSpacing.sm),
                        FilterPill(
                          label: q.name,
                          count: q.count,
                          selected: _qualification == q.id,
                          onTap: () {
                            _qualification = q.id;
                            _queryChanged();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(child: _ResultCount(count: _total)),
                    SortButton(
                      value: _sort,
                      onChanged: (sort) {
                        _sort = sort;
                        _queryChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading && _courses.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_error != null)
                  Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => _load(reset: _courses.isEmpty),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                if (!_loading && _error == null && _courses.isEmpty)
                  _NoResults(onClear: _clearSearchAndFilters),
                _CourseGrid(courses: _courses),
                if (_courses.isNotEmpty && _page < _lastPage)
                  TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: Text(_loading ? 'Loading…' : 'Load more courses'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Showing 7 courses", with the number in bold navy.
class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Showing ',
        children: [
          TextSpan(
            text: '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          TextSpan(text: count == 1 ? ' course' : ' courses'),
        ],
      ),
      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
    );
  }
}

/// Course cards in one column on phones, two columns on wider screens.
class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.courses});

  final List<CatalogueCourse> courses;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.lg;
        final columns = constraints.maxWidth >= AppSpacing.twoColumnBreakpoint
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final course in courses)
              SizedBox(
                width: cardWidth,
                child: CourseCard(
                  course: course,
                  // push (not pushReplacement) keeps this screen underneath,
                  // so the back button returns to the list.
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          MemberCourseScreen(courseId: course.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown when the search and filters match nothing.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 36)),
          const SizedBox(height: AppSpacing.md),
          const Text('No courses found', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Try a different search or filter.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear search & filters'),
          ),
        ],
      ),
    );
  }
}
