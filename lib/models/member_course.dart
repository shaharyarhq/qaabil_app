import 'objective_resources.dart';

/// Course content and optional private member progress.
class LearningProgress {
  const LearningProgress({
    required this.total,
    required this.started,
    required this.notStarted,
    required this.behind,
    required this.practice,
    required this.mastery,
    required this.coveragePercent,
    required this.masteryPercent,
  });
  final int total, started, notStarted, behind, practice, mastery;
  final int coveragePercent, masteryPercent;

  factory LearningProgress.fromJson(Map<String, dynamic> json) =>
      LearningProgress(
        total: json['total'] as int,
        started: json['started'] as int,
        notStarted: json['not_started'] as int,
        behind: json['behind'] as int,
        practice: json['practice'] as int,
        mastery: json['mastery'] as int,
        coveragePercent: json['coverage_percent'] as int,
        masteryPercent: json['mastery_percent'] as int,
      );
}

class MemberCourse {
  const MemberCourse({
    required this.id,
    required this.name,
    this.progress,
    this.qualification,
    this.description = '',
    this.notes = const [],
    this.sections = const [],
  });
  final int id;
  final String name;
  final String? qualification;
  final String description;
  final List<LessonNote> notes;
  final LearningProgress? progress;
  final List<OutlineSection> sections;

  factory MemberCourse.fromJson(Map<String, dynamic> json) => MemberCourse(
    id: json['id'] as int,
    name: json['name'] as String,
    qualification: json['qualification'] as String?,
    description: json['description'] as String? ?? '',
    notes: _notes(json),
    progress: json['progress'] == null
        ? null
        : LearningProgress.fromJson(json['progress'] as Map<String, dynamic>),
    sections: (json['sections'] as List<dynamic>? ?? [])
        .map((s) => OutlineSection.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

class OutlineSection {
  const OutlineSection({
    required this.id,
    required this.name,
    required this.chapters,
    this.notes = const [],
  });
  final int id;
  final String name;
  final List<OutlineChapter> chapters;
  final List<LessonNote> notes;
  factory OutlineSection.fromJson(Map<String, dynamic> json) => OutlineSection(
    id: json['id'] as int,
    name: json['name'] as String,
    notes: _notes(json),
    chapters: (json['chapters'] as List<dynamic>)
        .map((c) => OutlineChapter.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class OutlineChapter {
  const OutlineChapter({
    required this.id,
    required this.name,
    required this.objectives,
    this.notes = const [],
  });
  final int id;
  final String name;
  final List<OutlineObjective> objectives;
  final List<LessonNote> notes;
  factory OutlineChapter.fromJson(Map<String, dynamic> json) => OutlineChapter(
    id: json['id'] as int,
    name: json['name'] as String,
    notes: _notes(json),
    objectives: (json['objectives'] as List<dynamic>)
        .map((o) => OutlineObjective.fromJson(o as Map<String, dynamic>))
        .toList(),
  );
}

class OutlineObjective {
  const OutlineObjective({
    required this.id,
    required this.name,
    required this.status,
  });
  final int id;
  final String name;
  final String status;
  String get statusLabel => switch (status) {
    'behind' => 'Behind',
    'practice' => 'Practice',
    'mastery' => 'Mastery',
    _ => 'Not started',
  };
  factory OutlineObjective.fromJson(Map<String, dynamic> json) =>
      OutlineObjective(
        id: json['id'] as int,
        name: json['name'] as String,
        status: json['status'] as String? ?? 'not_started',
      );
}

class MemberCoursePage {
  const MemberCoursePage({
    required this.courses,
    required this.page,
    required this.lastPage,
    required this.total,
  });
  final List<MemberCourse> courses;
  final int page, lastPage, total;
  factory MemberCoursePage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return MemberCoursePage(
      courses: (json['data'] as List<dynamic>)
          .map((c) => MemberCourse.fromJson(c as Map<String, dynamic>))
          .toList(),
      page: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
      total: meta['total'] as int,
    );
  }
}

List<LessonNote> _notes(Map<String, dynamic> json) =>
    (json['notes'] as List<dynamic>? ?? [])
        .map((note) => LessonNote.fromJson(note as Map<String, dynamic>))
        .toList();
