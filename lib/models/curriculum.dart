/// The building blocks of a course, matching how qaabil.io organises it:
///
///   Course
///   └── Section          e.g. "Number"
///       └── Chapter      e.g. "Fractions and percentages"
///           └── Learning objective  e.g. "1.1 Convert between…"
library;

/// One thing a student should be able to do after a chapter.
class LearningObjective {
  const LearningObjective({
    required this.code,
    required this.title,
    this.youtubeVideoId,
  });

  /// Short number shown before the title, e.g. "1.1".
  final String code;
  final String title;

  /// Optional demo video. This is the part after `v=` in a YouTube link,
  /// e.g. "eNEgvVJI_zw" for youtube.com/watch?v=eNEgvVJI_zw.
  final String? youtubeVideoId;
}

/// A chapter inside a section. Holds one or more learning objectives.
class Chapter {
  const Chapter({required this.title, required this.objectives});

  final String title;
  final List<LearningObjective> objectives;
}

/// A group of related chapters. Named `CourseSection` (not `Section`)
/// to keep the name clear when reading screen code.
class CourseSection {
  const CourseSection({required this.title, required this.chapters});

  final String title;
  final List<Chapter> chapters;
}
