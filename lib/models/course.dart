import 'curriculum.dart';

/// The exam board / level a course belongs to. Used by the filter pills.
enum Qualification {
  igcse('Cambridge IGCSE'),
  aLevel('Cambridge A-Level');

  const Qualification(this.label);

  /// The name shown to the user.
  final String label;
}

/// A single course shown in the app.
class Course {
  const Course({
    required this.title,
    required this.description,
    required this.qualification,
    required this.curriculum,
    required this.videos,
    required this.addedOn,
  });

  final String title;
  final String description;
  final Qualification qualification;
  final int videos;

  /// The sections → chapters → objectives shown on the course page.
  final List<CourseSection> curriculum;

  // The counts are worked out from [curriculum], so they can never
  // disagree with what the course page shows.
  int get sections => curriculum.length;

  int get chapters {
    var total = 0;
    for (final section in curriculum) {
      total += section.chapters.length;
    }
    return total;
  }

  int get objectives {
    var total = 0;
    for (final section in curriculum) {
      for (final chapter in section.chapters) {
        total += chapter.objectives.length;
      }
    }
    return total;
  }

  /// When the course was published. Used for "Newest first" sorting.
  final DateTime addedOn;
}
