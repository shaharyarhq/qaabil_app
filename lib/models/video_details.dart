import 'objective_resources.dart';

class CourseContext {
  const CourseContext(this.id, this.name);
  final int id;
  final String name;
  factory CourseContext.fromJson(Map<String, dynamic> json) =>
      CourseContext(json['id'] as int, json['name'] as String);
}

class VideoMaterial extends LessonNote {
  const VideoMaterial({
    required super.id,
    required super.name,
    required super.size,
    required super.mime,
    required this.kind,
  });
  final String kind;
  String get label => switch (kind) {
    'learning_materials' => 'Learning material',
    'quiz_attachments' => 'Video notes',
    _ => 'Objective notes',
  };
  factory VideoMaterial.fromJson(Map<String, dynamic> json) => VideoMaterial(
    id: json['id'] as int,
    name: json['name'] as String,
    size: json['size'] as int,
    mime: json['mime'] as String,
    kind: json['kind'] as String,
  );
}

class VideoDetails {
  const VideoDetails({
    required this.description,
    required this.status,
    required this.course,
    required this.section,
    required this.chapter,
    required this.objective,
    required this.materials,
    required this.related,
    required this.relatedTotal,
    this.language,
    this.submittedAt,
    this.approvedBy,
    this.quizUrl,
  });
  final String description, status;
  final String? language, approvedBy;
  final DateTime? submittedAt;
  final Uri? quizUrl;
  final CourseContext course, section, chapter, objective;
  final List<VideoMaterial> materials;
  final List<LessonVideo> related;
  final int relatedTotal;
  factory VideoDetails.fromJson(Map<String, dynamic> json) {
    final link = Uri.tryParse(json['quiz_url'] as String? ?? '');
    return VideoDetails(
      description: json['description'] as String? ?? '',
      status: json['status'] as String,
      course: CourseContext.fromJson(json['course'] as Map<String, dynamic>),
      section: CourseContext.fromJson(json['section'] as Map<String, dynamic>),
      chapter: CourseContext.fromJson(json['chapter'] as Map<String, dynamic>),
      objective: CourseContext.fromJson(
        json['objective'] as Map<String, dynamic>,
      ),
      materials: (json['materials'] as List)
          .map((m) => VideoMaterial.fromJson(m as Map<String, dynamic>))
          .toList(),
      related: (json['related'] as List)
          .map((v) => LessonVideo.fromJson(v as Map<String, dynamic>))
          .toList(),
      relatedTotal: json['related_total'] as int,
      language: json['language'] as String?,
      approvedBy: json['approved_by'] as String?,
      submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
      quizUrl:
          link != null &&
              link.scheme == 'https' &&
              link.host.isNotEmpty &&
              link.userInfo.isEmpty
          ? link
          : null,
    );
  }
}

class VideoReview {
  const VideoReview({
    required this.id,
    required this.author,
    required this.text,
    required this.rating,
    required this.isMine,
    this.createdAt,
  });
  final int id, rating;
  final String author, text;
  final bool isMine;
  final DateTime? createdAt;
  factory VideoReview.fromJson(Map<String, dynamic> json) => VideoReview(
    id: json['id'] as int,
    author: json['author'] as String,
    text: json['review'] as String? ?? '',
    rating: json['rating'] as int,
    isMine: json['is_mine'] == true,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );
}

class VideoReviewPage {
  const VideoReviewPage({
    required this.reviews,
    required this.total,
    required this.average,
    required this.counts,
    required this.page,
    required this.lastPage,
    this.ownReview,
  });
  final List<VideoReview> reviews;
  final VideoReview? ownReview;
  final int total, page, lastPage;
  final double average;
  final List<int> counts;
  factory VideoReviewPage.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    final meta = json['meta'] as Map<String, dynamic>;
    final counts = (summary['counts'] as List).cast<int>();
    if (counts.length != 5) {
      throw const FormatException('Invalid rating summary');
    }
    return VideoReviewPage(
      reviews: (json['data'] as List)
          .map((r) => VideoReview.fromJson(r as Map<String, dynamic>))
          .toList(),
      ownReview: json['own_review'] == null
          ? null
          : VideoReview.fromJson(json['own_review'] as Map<String, dynamic>),
      total: summary['total'] as int,
      average: (summary['average'] as num).toDouble(),
      counts: counts,
      page: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
    );
  }
}
