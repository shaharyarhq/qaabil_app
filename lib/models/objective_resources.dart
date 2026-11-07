class LessonVideo {
  const LessonVideo({
    required this.id,
    required this.title,
    this.creator,
    this.thumbnail,
  });
  final int id;
  final String title;
  final String? creator, thumbnail;
  factory LessonVideo.fromJson(Map<String, dynamic> json) => LessonVideo(
    id: json['id'] as int,
    title: json['title'] as String,
    creator: json['creator'] as String?,
    thumbnail: json['thumbnail'] as String?,
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
  });
  final String name;
  final List<LessonVideo> videos;
  final List<LessonNote> notes;
  factory ObjectiveResources.fromJson(Map<String, dynamic> json) =>
      ObjectiveResources(
        name: (json['objective'] as Map<String, dynamic>)['name'] as String,
        videos: (json['videos'] as List)
            .map((v) => LessonVideo.fromJson(v as Map<String, dynamic>))
            .toList(),
        notes: (json['notes'] as List)
            .map((n) => LessonNote.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}

class VideoPlayback {
  const VideoPlayback({
    required this.title,
    required this.allowed,
    this.creator,
    this.youtubeId,
    this.reason,
  });
  final String title;
  final String? creator, youtubeId, reason;
  final bool allowed;
  factory VideoPlayback.fromJson(Map<String, dynamic> json) {
    final access = json['access'] as Map<String, dynamic>;
    final id = json['youtube_id'] as String?;
    final allowed =
        access['allowed'] == true &&
        id != null &&
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
    return VideoPlayback(
      title: json['title'] as String,
      creator: json['creator'] as String?,
      youtubeId: allowed ? id : null,
      allowed: allowed,
      reason: access['reason'] as String?,
    );
  }
}
