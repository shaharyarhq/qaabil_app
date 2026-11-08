class VideoSubmission {
  const VideoSubmission({
    required this.id,
    required this.title,
    required this.status,
    required this.contextLabels,
    this.submittedAt,
  });

  final int id;
  final String title;
  final String? status;
  final List<String> contextLabels;
  final DateTime? submittedAt;

  factory VideoSubmission.fromJson(Map<String, dynamic> json) =>
      VideoSubmission(
        id: json['id'] as int,
        title: json['title'] as String,
        status: json['status'] as String?,
        contextLabels: [
          for (final field in ['course', 'section', 'chapter', 'objective'])
            if (json[field] case final String name when name.trim().isNotEmpty)
              name,
        ],
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
