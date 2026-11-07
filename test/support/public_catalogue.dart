import 'dart:convert';

import 'package:http/http.dart' as http;

Map<String, dynamic> publicCourse({
  int id = 18,
  String name = 'Backend Accounting',
}) => {
  'id': id,
  'name': name,
  'description': 'From the server',
  'qualification': 'Backend Qualification',
  'sections_count': 1,
  'chapters_count': 1,
  'videos_count': 2,
  'created_at': '2026-10-01T00:00:00Z',
};
Map<String, dynamic> publicPage({
  List<Map<String, dynamic>>? courses,
  int page = 1,
  int last = 1,
}) => {
  'data': courses ?? [publicCourse()],
  'meta': {
    'current_page': page,
    'last_page': last,
    'total': last == 1 ? (courses ?? [publicCourse()]).length : 2,
    'catalogue_total': 2,
  },
  'qualifications': [
    {'id': 9, 'name': 'Backend Qualification', 'courses_count': 2},
  ],
};
http.Response publicJson(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
http.Response? defaultPublicResponse(http.Request request) =>
    request.url.path == '/api/v1/courses' ? publicJson(publicPage()) : null;
