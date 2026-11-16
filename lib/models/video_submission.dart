class VideoSubmission {
  const VideoSubmission({
    required this.id,
    required this.title,
    required this.status,
    this.course,
    this.section,
    this.chapter,
    this.objective,
    this.thumbnail,
    this.approvedBy,
    this.submittedAt,
    this.courseId,
    this.objectiveId,
    this.videoUrl,
    this.description,
    this.language,
    this.focus,
  });

  final int id;
  final String title;
  final String? status;
  final String? course, section, chapter, objective, thumbnail, approvedBy;
  final DateTime? submittedAt;
  final int? courseId, objectiveId;
  final String? videoUrl, description, language, focus;

  factory VideoSubmission.fromJson(Map<String, dynamic> json) =>
      VideoSubmission(
        id: json['id'] as int,
        title: json['title'] as String,
        status: json['status'] as String?,
        course: json['course'] as String?,
        section: json['section'] as String?,
        chapter: json['chapter'] as String?,
        objective: json['objective'] as String?,
        thumbnail: json['thumbnail'] as String?,
        approvedBy: json['approved_by'] as String?,
        courseId: json['course_id'] as int?,
        objectiveId: json['objective_id'] as int?,
        videoUrl: json['video_url'] as String?,
        description: json['description'] as String?,
        language: json['language'] as String?,
        focus: json['focus_of_the_video'] as String?,
        submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
      );
}

class SubmissionPage {
  const SubmissionPage(this.items, this.page, this.lastPage);

  final List<VideoSubmission> items;
  final int page, lastPage;

  factory SubmissionPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return SubmissionPage(
      (json['data'] as List)
          .map((item) => VideoSubmission.fromJson(item as Map<String, dynamic>))
          .toList(),
      meta['current_page'] as int,
      meta['last_page'] as int,
    );
  }
}
