/// Public course metadata returned by the backend; no sample curriculum.
class CatalogueCourse {
  const CatalogueCourse({
    required this.id,
    required this.name,
    required this.description,
    required this.sections,
    required this.chapters,
    required this.videos,
    this.qualification,
    this.addedOn,
  });
  final int id, sections, chapters, videos;
  final String name, description;
  final String? qualification;
  final DateTime? addedOn;
  factory CatalogueCourse.fromJson(Map<String, dynamic> json) =>
      CatalogueCourse(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        qualification: json['qualification'] as String?,
        sections: json['sections_count'] as int,
        chapters: json['chapters_count'] as int,
        videos: json['videos_count'] as int,
        addedOn: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}

class CatalogueQualification {
  const CatalogueQualification({
    required this.id,
    required this.name,
    required this.count,
  });
  final int id, count;
  final String name;
  factory CatalogueQualification.fromJson(Map<String, dynamic> json) =>
      CatalogueQualification(
        id: json['id'] as int,
        name: json['name'] as String,
        count: json['courses_count'] as int,
      );
}

class CataloguePage {
  const CataloguePage({
    required this.courses,
    required this.qualifications,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.catalogueTotal,
  });
  final List<CatalogueCourse> courses;
  final List<CatalogueQualification> qualifications;
  final int page, lastPage, total, catalogueTotal;
  factory CataloguePage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return CataloguePage(
      courses: (json['data'] as List)
          .map((c) => CatalogueCourse.fromJson(c as Map<String, dynamic>))
          .toList(),
      qualifications: (json['qualifications'] as List)
          .map(
            (q) => CatalogueQualification.fromJson(q as Map<String, dynamic>),
          )
          .toList(),
      page: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
      total: meta['total'] as int,
      catalogueTotal: meta['catalogue_total'] as int,
    );
  }
}
