class LessonVideo {
  const LessonVideo({
    required this.id,
    required this.title,
    this.creator,
    this.creatorId,
    this.language,
    this.focus,
    this.thumbnail,
    this.averageRating,
    this.reviewCount = 0,
    this.submittedAt,
  });
  final int id;
  final String title;
  final String? creator, language, thumbnail, focus;
  final int? creatorId;
  final double? averageRating;
  final int reviewCount;
  final DateTime? submittedAt;
  factory LessonVideo.fromJson(Map<String, dynamic> json) => LessonVideo(
    id: json['id'] as int,
    title: json['title'] as String,
    creator: json['creator'] as String?,
    creatorId: json['creator_id'] as int?,
    language: json['language'] as String?,
    focus: json['focus'] as String?,
    thumbnail: json['thumbnail'] as String?,
    averageRating: (json['average_rating'] as num?)?.toDouble(),
    reviewCount: json['review_count'] as int? ?? 0,
    submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? ''),
  );
}

class LessonNote {
  const LessonNote({
    required this.id,
    required this.name,
    required this.size,
    required this.mime,
  });
  final int id, size;
  final String name, mime;
  factory LessonNote.fromJson(Map<String, dynamic> json) => LessonNote(
    id: json['id'] as int,
    name: json['name'] as String,
    size: json['size'] as int,
    mime: json['mime'] as String,
  );
}

class ObjectiveResources {
  const ObjectiveResources({
    required this.name,
    required this.videos,
    required this.notes,
    this.description = '',
    this.courseId,
    this.courseName,
    this.chapterName,
  });

  final String name, description;
  final int? courseId;
  final String? courseName, chapterName;
  final List<LessonVideo> videos;
  final List<LessonNote> notes;

  factory ObjectiveResources.fromJson(Map<String, dynamic> json) {
    final objective = json['objective'] as Map<String, dynamic>;
    return ObjectiveResources(
      name: objective['name'] as String,
      description: objective['description'] as String? ?? '',
      courseId: objective['course_id'] as int?,
      courseName: objective['course_name'] as String?,
      chapterName: objective['chapter_name'] as String?,
      videos: (json['videos'] as List)
          .map((v) => LessonVideo.fromJson(v as Map<String, dynamic>))
          .toList(),
      notes: (json['notes'] as List)
          .map((n) => LessonNote.fromJson(n as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VideoPlayback {
  const VideoPlayback({
    required this.title,
    required this.allowed,
    this.creator,
    this.youtubeId,
    this.bunnyEmbedUrl,
    this.reason,
  });
  final String title;
  final String? creator, youtubeId, reason;
  final Uri? bunnyEmbedUrl;
  final bool allowed;
  static Uri? parseBunnyEmbedUrl(String? value) {
    final pattern = RegExp(
      r'^https://iframe\.mediadelivery\.net/embed/[0-9]+/[a-fA-F0-9-]{36}$',
    );
    return value != null && pattern.hasMatch(value) ? Uri.parse(value) : null;
  }

  factory VideoPlayback.fromJson(Map<String, dynamic> json) {
    final access = json['access'] as Map<String, dynamic>;
    final id = json['youtube_id'] as String?;
    final bunny = parseBunnyEmbedUrl(json['bunny_embed_url'] as String?);
    final validYoutube =
        id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
    final allowed =
        access['allowed'] == true && (validYoutube || bunny != null);
    return VideoPlayback(
      title: json['title'] as String,
      creator: json['creator'] as String?,
      youtubeId: allowed && validYoutube ? id : null,
      bunnyEmbedUrl: allowed ? bunny : null,
      allowed: allowed,
      reason: access['reason'] as String?,
    );
  }
}
