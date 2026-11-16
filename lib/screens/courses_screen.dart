import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/searchable_select.dart';

import '../auth/member_session.dart';
import '../models/catalogue_course.dart';
import '../models/course_sort.dart';
import '../services/member_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/course_card.dart';
import '../widgets/qaabil_app_bar.dart';
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
  int _version = 0, _page = 0, _lastPage = 1, _total = 0;
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
      });
    } on ApiException catch (e) {
      if (mounted && version == _version) setState(() => _error = e.message);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _queryChanged();
  }

  void _setQualification(int? value) {
    _qualification = value;
    _queryChanged();
  }

  void _setSort(CourseSort value) {
    _sort = value;
    _queryChanged();
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    _qualification = null;
    _sort = CourseSort.newest;
    _queryChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.of(context).background,
    appBar: MediaQuery.sizeOf(context).width >= 640
        ? const QaabilAppBar(height: 76, logoHeight: 44)
        : const QaabilAppBar(),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
        final inset = math.max(24.0, (width - 1440) / 2 + 24);
        final search = _searchField();
        final filters = _filters();
        final hasFilters =
            _searchController.text.trim().isNotEmpty ||
            _qualification != null ||
            _sort != CourseSort.newest;
        return RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              inset,
              width >= 640 ? 63 : 56,
              inset,
              56,
            ),
            children: [
              _CatalogueHeader(
                count: _total,
                showCount: !largeText && width >= 720,
              ),
              const SizedBox(height: 32),
              if (!largeText && width >= 640)
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: 342, child: filters),
                  ],
                )
              else ...[
                search,
                const SizedBox(height: 12),
                filters,
              ],
              if (hasFilters) ...[const SizedBox(height: 12), _activeFilters()],
              const SizedBox(height: 32),
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
              _CourseGrid(
                courses: _courses,
                columns: !largeText && width >= 1024
                    ? 4
                    : width >= 720
                    ? 2
                    : 1,
              ),
              if (_courses.isNotEmpty && _page < _lastPage)
                TextButton(
                  onPressed: _loading ? null : () => _load(),
                  child: Text(_loading ? 'Loading…' : 'Load more courses'),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _searchField() => TextField(
    controller: _searchController,
    onChanged: (_) => _queryChanged(debounce: true),
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    textInputAction: TextInputAction.search,
    style: AppTextStyles.body.copyWith(
      color: AppPalette.of(context).textPrimary,
    ),
    decoration: InputDecoration(
      hintText: 'Search courses…',
      hintStyle: AppTextStyles.body.copyWith(
        color: AppPalette.of(context).textMuted,
      ),
      filled: true,
      fillColor: AppPalette.of(context).surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      prefixIcon: Icon(
        Icons.search,
        size: 19,
        color: AppPalette.of(context).textMuted,
      ),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close, size: 16),
            ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppPalette.of(context).border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppPalette.of(context).accent),
      ),
    ),
  );

  String? get _qualificationName {
    for (final qualification in _qualifications) {
      if (qualification.id == _qualification) return qualification.name;
    }
    return null;
  }

  Widget _filters() => Row(
    children: [
      Expanded(
        flex: 7,
        child: _CatalogueSelect<int>(
          tooltip: 'Filter by qualification',
          icon: Icons.school_outlined,
          label: _qualificationName ?? 'All qualifications',
          value: _qualification ?? 0,
          options: [
            (0, 'All qualifications'),
            for (final qualification in _qualifications)
              (
                qualification.id,
                '${qualification.name} (${qualification.count})',
              ),
          ],
          onSelected: (value) => _setQualification(value == 0 ? null : value),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 5,
        child: _CatalogueSelect<CourseSort>(
          tooltip: 'Sort courses',
          icon: Icons.sort_rounded,
          label: _sort.label,
          value: _sort,
          options: [for (final sort in CourseSort.values) (sort, sort.label)],
          onSelected: _setSort,
        ),
      ),
    ],
  );

  Widget _activeFilters() => Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'ACTIVE FILTERS',
        style: AppTextStyles.eyebrow.copyWith(
          fontSize: 10,
          letterSpacing: .8,
          color: AppPalette.of(context).textMuted,
        ),
      ),
      if (_searchController.text.trim().isNotEmpty)
        _CatalogueFilterBadge(
          label: '“${_searchController.text.trim()}”',
          icon: Icons.search,
          color: AppPalette.of(context).accent,
          tint: AppPalette.of(context).navyTint,
          removeLabel: 'Remove search filter',
          onRemove: _clearSearch,
        ),
      if (_qualification != null)
        _CatalogueFilterBadge(
          label: _qualificationName ?? 'Qualification',
          icon: Icons.school_outlined,
          color: AppPalette.of(context).teal,
          tint: AppPalette.of(context).tealTint,
          removeLabel: 'Remove qualification filter',
          onRemove: () => _setQualification(null),
        ),
      if (_sort != CourseSort.newest)
        _CatalogueFilterBadge(
          label: _sort.label,
          icon: Icons.sort_rounded,
          color: AppPalette.of(context).amberText,
          tint: AppPalette.of(context).amberTint,
          removeLabel: 'Remove sort filter',
          onRemove: () => _setSort(CourseSort.newest),
        ),
      TextButton(
        onPressed: _clearSearchAndFilters,
        child: Text(
          'Clear all',
          style: AppTextStyles.caption.copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ],
  );
}

class _CatalogueHeader extends StatelessWidget {
  const _CatalogueHeader({required this.count, required this.showCount});

  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          const Text('ALL COURSES', style: AppTextStyles.eyebrow),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  text: 'Start learning ',
                  children: [
                    TextSpan(
                      text: 'today',
                      style: TextStyle(
                        color: AppPalette.of(context).accent,
                        fontFamily: AppTextStyles.serif,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFF59E0B),
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
                style: AppTextStyles.heading.copyWith(
                  fontSize: 36,
                  color: AppPalette.of(context).textPrimary,
                ),
              ),
            ),
          ),
          if (showCount) ...[
            const SizedBox(width: 16),
            _ResultCount(count: count),
          ],
        ],
      ),
    ],
  );
}

class _CatalogueSelect<T> extends StatelessWidget {
  const _CatalogueSelect({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String tooltip, label;
  final IconData icon;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SearchableSelect<T>(
    label: tooltip,
    value: value,
    options: {for (final (value, label) in options) value: label},
    onChanged: (value) => onSelected(value as T),
    child: Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.of(context).surface,
        border: Border.all(color: AppPalette.of(context).border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppPalette.of(context).textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: AppPalette.of(context).textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            Icons.expand_more,
            size: 14,
            color: AppPalette.of(context).textMuted,
          ),
        ],
      ),
    ),
  );
}

class _CatalogueFilterBadge extends StatelessWidget {
  const _CatalogueFilterBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.removeLabel,
    required this.onRemove,
  });

  final String label, removeLabel;
  final IconData icon;
  final Color color, tint;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InputChip(
    avatar: Icon(icon, size: 14, color: color),
    label: Text(label, overflow: TextOverflow.ellipsis),
    labelStyle: AppTextStyles.caption.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    ),
    deleteIcon: Icon(Icons.close, color: color, size: 14),
    deleteButtonTooltipMessage: removeLabel,
    onDeleted: onRemove,
    backgroundColor: tint,
    side: BorderSide(color: color.withValues(alpha: .18)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppPalette.of(context).accent,
            ),
          ),
          TextSpan(text: count == 1 ? ' course' : ' courses'),
        ],
      ),
      style: AppTextStyles.body.copyWith(
        color: AppPalette.of(context).textMuted,
      ),
    );
  }
}

/// Course cards flow into additional columns as the window gets wider.
class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.courses, required this.columns});

  final List<CatalogueCourse> courses;
  final int columns;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 24,
    children: [
      for (var start = 0; start < courses.length; start += columns)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: [
              for (var index = start; index < start + columns; index++)
                Expanded(
                  child: index < courses.length
                      ? _card(context, courses[index])
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _card(BuildContext context, CatalogueCourse course) => CourseCard(
    course: course,
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberCourseScreen(courseId: course.id),
      ),
    ),
  );
}

/// Shown when the search and filters match nothing.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppPalette.of(context).surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.of(context).border),
            ),
            child: Icon(
              Icons.search,
              size: 28,
              color: AppPalette.of(context).accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('No courses found', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Try a different search or filter.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onClear,
            child: const Text('Clear search & filters'),
          ),
        ],
      ),
    );
  }
}
