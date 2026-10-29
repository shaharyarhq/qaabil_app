import 'package:flutter/material.dart';

import '../data/mock_courses.dart';
import '../models/course.dart';
import '../models/course_sort.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/course_card.dart';
import '../widgets/filter_pill.dart';
import '../widgets/qaabil_logo.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/sort_button.dart';
import 'course_detail_screen.dart';

/// Lists all courses with a search bar, qualification filters and sorting,
/// following the layout of qaabil.io/courses.
///
/// This is a StatefulWidget because the search text and chosen filters
/// change while the user is on the screen.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _searchController = TextEditingController();

  /// The selected qualification. `null` means "All".
  Qualification? _qualification;

  CourseSort _sort = CourseSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// The courses to show after applying search, filter and sort.
  List<Course> get _visibleCourses {
    final query = _searchController.text.trim().toLowerCase();

    final courses = mockCourses.where((course) {
      final matchesFilter =
          _qualification == null || course.qualification == _qualification;
      final matchesSearch =
          query.isEmpty ||
          course.title.toLowerCase().contains(query) ||
          course.description.toLowerCase().contains(query) ||
          course.qualification.label.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();

    courses.sort(
      (a, b) => _sort == CourseSort.newest
          ? b.addedOn.compareTo(a.addedOn)
          : a.addedOn.compareTo(b.addedOn),
    );
    return courses;
  }

  int _countFor(Qualification qualification) {
    return mockCourses.where((c) => c.qualification == qualification).length;
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() => _qualification = null);
  }

  @override
  Widget build(BuildContext context) {
    final courses = _visibleCourses;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 64, title: const QaabilLogo(height: 36)),
      // Tapping outside the search box closes the keyboard.
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.gridMaxWidth,
            ),
            child: ListView(
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
                  // Rebuild so the list (and the ✕ button) update as you type.
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_searchController.clear),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildQualificationFilters(),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(child: _ResultCount(count: courses.length)),
                    SortButton(
                      value: _sort,
                      onChanged: (sort) => setState(() => _sort = sort),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (courses.isEmpty)
                  _NoResults(onClear: _clearSearchAndFilters)
                else
                  _CourseGrid(courses: courses),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "All 7", "Cambridge IGCSE 4", "Cambridge A-Level 3" in a row that
  /// scrolls sideways if it doesn't fit.
  Widget _buildQualificationFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterPill(
            label: 'All',
            count: mockCourses.length,
            selected: _qualification == null,
            onTap: () => setState(() => _qualification = null),
          ),
          for (final qualification in Qualification.values) ...[
            const SizedBox(width: AppSpacing.sm),
            FilterPill(
              label: qualification.label,
              count: _countFor(qualification),
              selected: _qualification == qualification,
              onTap: () => setState(() => _qualification = qualification),
            ),
          ],
        ],
      ),
    );
  }
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

  final List<Course> courses;

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
                      builder: (context) => CourseDetailScreen(course: course),
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
