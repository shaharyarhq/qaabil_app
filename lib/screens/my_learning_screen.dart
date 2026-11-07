import 'package:flutter/material.dart';

import '../auth/member_session.dart';
import '../models/member_course.dart';
import '../services/member_api.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/learning_progress.dart';
import '../widgets/qaabil_app_bar.dart';
import '../widgets/section_header.dart';
import 'member_area_screen.dart';
import 'member_course_screen.dart';

class MyLearningScreen extends StatefulWidget {
  const MyLearningScreen({super.key, required this.onBrowseCourses});
  final VoidCallback onBrowseCourses;
  @override
  State<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends State<MyLearningScreen> {
  final List<MemberCourse> _courses = [];
  MemberSession? _session;
  int? _memberId;
  int _requestVersion = 0;
  int _page = 0, _lastPage = 1;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = SessionScope.of(context);
    final id = _session!.member?.id;
    if (id != _memberId) {
      _memberId = id;
      _requestVersion++;
      _courses.clear();
      _page = 0;
      _loading = false;
      _error = null;
      if (id != null) _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_memberId == null || (_loading && !reset)) return;
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _courses.clear();
        _page = 0;
      }
    });
    try {
      final result = await _session!.courses(page: reset ? 1 : _page + 1);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _courses.addAll(result.courses);
        _page = result.page;
        _lastPage = result.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted && version == _requestVersion) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
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
              key: const PageStorageKey('member-learning'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                const SectionHeader(
                  eyebrow: 'YOUR JOURNEY',
                  title: 'My Learning',
                  accent: '',
                  subtitle: 'Your courses and saved objective progress.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_loading && _courses.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_error != null)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_error!, style: AppTextStyles.body),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => _load(reset: _courses.isEmpty),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (!_loading && _error == null && _courses.isEmpty)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'No learning progress yet',
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Courses appear here once you have saved objective progress on Qaabil. Your existing website progress will appear here too.',
                          style: AppTextStyles.body,
                        ),
                        TextButton(
                          onPressed: widget.onBrowseCourses,
                          child: const Text('Browse courses'),
                        ),
                      ],
                    ),
                  ),
                for (final course in _courses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(course.name, style: AppTextStyles.cardTitle),
                          if (course.qualification != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              course.qualification!,
                              style: AppTextStyles.caption,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          LearningProgressView(progress: course.progress!),
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    MemberCourseScreen(courseId: course.id),
                              ),
                            ),
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('Open course'),
                          ),
                        ],
                      ),
                    ),
                  ),
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
    );
  }
}
