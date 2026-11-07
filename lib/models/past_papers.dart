import 'objective_resources.dart';

class PaperDocument extends LessonNote {
  const PaperDocument({
    required super.id,
    required super.name,
    required super.size,
    required super.mime,
    required this.kind,
  });
  final String kind;
  String get label => switch (kind) {
    'question_paper' => 'Question paper',
    'marking_scheme' => 'Marking scheme',
    'examiners_report' => "Examiner’s report",
    _ => 'Document',
  };
  factory PaperDocument.fromJson(Map<String, dynamic> json) => PaperDocument(
    id: json['id'] as int,
    name: json['name'] as String,
    size: json['size'] as int,
    mime: json['mime'] as String,
    kind: json['kind'] as String,
  );
}

class PaperCourse {
  const PaperCourse({required this.id, required this.name});
  final int id;
  final String name;
  factory PaperCourse.fromJson(Map<String, dynamic> json) =>
      PaperCourse(id: json['id'] as int, name: json['name'] as String);
}

class PastPaper {
  const PastPaper({
    required this.id,
    required this.name,
    required this.course,
    required this.year,
    required this.sitting,
    required this.details,
    required this.documents,
    this.totalMarks,
  });
  final int id, year;
  final String name, sitting, details;
  final PaperCourse course;
  final int? totalMarks;
  final List<PaperDocument> documents;
  factory PastPaper.fromJson(Map<String, dynamic> json) => PastPaper(
    id: json['id'] as int,
    name: json['paper_name'] as String,
    course: PaperCourse.fromJson(json['course'] as Map<String, dynamic>),
    year: json['year'] as int,
    sitting: json['sitting'] as String? ?? '',
    details: json['other_details'] as String? ?? '',
    totalMarks: (json['total_marks'] as num?)?.toInt(),
    documents: (json['documents'] as List<dynamic>)
        .map((file) => PaperDocument.fromJson(file as Map<String, dynamic>))
        .toList(),
  );
}

class PastPaperPage {
  const PastPaperPage({
    required this.papers,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.courses,
    required this.years,
    required this.sittings,
  });
  final List<PastPaper> papers;
  final int page, lastPage, total;
  final List<PaperCourse> courses;
  final List<int> years;
  final List<String> sittings;
  factory PastPaperPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    final filters = json['filters'] as Map<String, dynamic>;
    return PastPaperPage(
      papers: (json['data'] as List<dynamic>)
          .map((p) => PastPaper.fromJson(p as Map<String, dynamic>))
          .toList(),
      page: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
      total: meta['total'] as int,
      courses: (filters['courses'] as List<dynamic>)
          .map((c) => PaperCourse.fromJson(c as Map<String, dynamic>))
          .toList(),
      years: (filters['years'] as List<dynamic>).map((y) => y as int).toList(),
      sittings: (filters['sittings'] as List<dynamic>).cast<String>(),
    );
  }
}
