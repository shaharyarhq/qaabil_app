import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../auth/member.dart';
import '../models/member_course.dart';
import '../models/catalogue_course.dart';
import '../models/objective_resources.dart';
import '../models/video_details.dart';
import '../models/past_papers.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
}

/// Configure the server at build time; credentials never go in the app code.
class MemberApi {
  MemberApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final String baseUrl;
  bool get configured => baseUrl.isNotEmpty;

  Uri _uri(String path, {bool public = false}) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const ApiException('The Qaabil service is not configured yet.');
    }
    // HTTP is permitted only for explicit debug builds against a local server.
    const release = bool.fromEnvironment('dart.vm.product');
    if (uri.scheme != 'https' && (release || uri.scheme != 'http')) {
      throw const ApiException(
        'A secure member service connection is required.',
      );
    }
    return Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/${public ? '' : 'member/'}$path',
    );
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String? token,
    Map<String, String>? body,
    bool post = false,
    bool delete = false,
    bool public = false,
  }) async {
    final uri = _uri(path, public: public);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final response =
          await (delete
                  ? _client.delete(uri, headers: headers)
                  : post
                  ? _client.post(uri, headers: headers, body: body)
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 20));
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const ApiException(
          'The member service returned an unexpected response.',
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      // Never show framework exception details from a development server.
      final message = switch (response.statusCode) {
        401 => 'Your session has expired. Please log in again.',
        403 =>
          path == 'login'
              ? 'This account cannot use member sign-in. Two-factor accounts are not supported yet.'
              : 'Your account cannot access this member feature.',
        404 => 'This resource is no longer available.',
        422 =>
          path.startsWith('past-papers')
              ? 'Please shorten the paper search or choose another filter.'
              : public
              ? 'Please use a shorter search or choose another course filter.'
              : path.contains('/reviews')
              ? ((data['errors'] as Map?)?['review'] is List &&
                        ((data['errors'] as Map)['review'] as List).contains(
                          'You have already reviewed this video.',
                        )
                    ? 'You have already reviewed this video.'
                    : 'Choose 1–5 stars and keep your review within 1,000 characters.')
              : 'The email or password is incorrect.',
        429 => 'Too many attempts. Please wait a minute and try again.',
        _ => 'The member service is unavailable. Please try again later.',
      };
      throw ApiException(message, status: response.statusCode);
    } on TimeoutException {
      throw const ApiException('The connection timed out. Please try again.');
    } on http.ClientException {
      throw const ApiException(
        'Cannot connect. Check your internet connection and try again.',
      );
    }
  }

  Future<CataloguePage> catalogue({
    String search = '',
    int? qualification,
    String sort = 'newest',
    int page = 1,
  }) async {
    final query = Uri(
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (qualification != null) 'qualification': '$qualification',
        'sort': sort,
        'page': '$page',
      },
    ).query;
    final data = await _request('courses?$query', public: true);
    try {
      return CataloguePage.fromJson(data);
    } catch (_) {
      throw const ApiException(
        'Could not read the course catalogue. Please try again.',
      );
    }
  }

  Future<MemberCourse> publicCourse(int id) async {
    final data = await _request('courses/$id', public: true);
    try {
      return MemberCourse.fromJson(data['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException('Could not read this course. Please try again.');
    }
  }

  Future<({String token, Member member})> login(
    String email,
    String password,
  ) async {
    final data = await _request(
      'login',
      post: true,
      body: {
        'email': email,
        'password': password,
        'device_name': 'Qaabil mobile',
      },
    );
    try {
      return (
        token: data['token'] as String,
        member: Member.fromJson(data['user'] as Map<String, dynamic>),
      );
    } catch (_) {
      throw const ApiException(
        'The member service returned an unexpected response.',
      );
    }
  }

  Future<Member> me(String token) async {
    final data = await _request('me', token: token);
    try {
      return Member.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'The member service returned an unexpected response.',
      );
    }
  }

  Future<PastPaperPage> pastPapers({
    required String token,
    String search = '',
    int? course,
    int? year,
    String? sitting,
    int page = 1,
  }) async {
    final query = Uri(
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (course != null) 'course': '$course',
        if (year != null) 'year': '$year',
        if (sitting != null && sitting.isNotEmpty) 'sitting': sitting,
        'page': '$page',
      },
    ).query;
    final data = await _request('past-papers?$query', token: token);
    try {
      return PastPaperPage.fromJson(data);
    } catch (_) {
      throw const ApiException('Could not read past papers. Please try again.');
    }
  }

  Future<Uint8List> paperDocument(
    String token,
    int paperId,
    PaperDocument file,
  ) {
    if (!{
      'question_paper',
      'marking_scheme',
      'examiners_report',
    }.contains(file.kind)) {
      throw const ApiException('This paper document is unavailable.');
    }
    return _download(token, 'past-papers/$paperId/files/${file.kind}');
  }

  Future<MemberCoursePage> courses(String token, {int page = 1}) async {
    final data = await _request('courses?page=$page', token: token);
    try {
      final page = MemberCoursePage.fromJson(data);
      if (page.courses.any((course) => course.progress == null)) {
        throw const FormatException('Missing member progress');
      }
      return page;
    } catch (_) {
      throw const ApiException(
        'The learning service returned an unexpected response.',
      );
    }
  }

  Future<MemberCourse> course(String token, int id) async {
    final data = await _request('courses/$id', token: token);
    try {
      return MemberCourse.fromJson(data['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'The learning service returned an unexpected response.',
      );
    }
  }

  Future<ObjectiveResources> resources(String token, int objectiveId) async {
    final data = await _request(
      'objectives/$objectiveId/resources',
      token: token,
    );
    try {
      return ObjectiveResources.fromJson(data['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'The learning service returned an unexpected response.',
      );
    }
  }

  Future<VideoPlayback> video(String token, int videoId) async {
    final data = await _request('videos/$videoId', token: token);
    try {
      return VideoPlayback.fromJson(data['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'The learning service returned an unexpected response.',
      );
    }
  }

  Future<VideoDetails> videoDetails(String token, int id) async {
    final data = await _request('videos/$id/details', token: token);
    try {
      return VideoDetails.fromJson(data['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'Could not read the video details. Please try again.',
      );
    }
  }

  Future<VideoReviewPage> videoReviews(
    String token,
    int id, {
    int page = 1,
  }) async {
    final data = await _request('videos/$id/reviews?page=$page', token: token);
    try {
      return VideoReviewPage.fromJson(data);
    } catch (_) {
      throw const ApiException('Could not read reviews. Please try again.');
    }
  }

  Future<void> submitVideoReview(
    String token,
    int id,
    int rating,
    String text,
  ) async {
    await _request(
      'videos/$id/reviews',
      token: token,
      post: true,
      body: {'rating': '$rating', 'review': text.trim()},
    );
  }

  Future<void> deleteVideoReview(String token, int id, int review) async {
    await _request('videos/$id/reviews/$review', token: token, delete: true);
  }

  Future<Uint8List> videoMaterial(String token, int id, VideoMaterial file) =>
      _download(
        token,
        'videos/$id/materials/${Uri.encodeComponent(file.kind)}/${file.id}',
      );

  Future<Uint8List> note(String token, int objectiveId, int noteId) =>
      _download(token, 'objectives/$objectiveId/notes/$noteId');

  Future<Uint8List> curriculumNote(
    String token,
    String kind,
    int resourceId,
    int noteId,
  ) {
    if (!{'course', 'section', 'chapter'}.contains(kind)) {
      throw const ApiException('These notes are unavailable.');
    }
    return _download(token, 'learning-notes/$kind/$resourceId/$noteId');
  }

  Future<Uint8List> _download(String token, String path) async {
    try {
      final response = await _client
          .get(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiException(
          'Your session has expired. Please log in again.',
          status: response.statusCode,
        );
      }
      if (response.statusCode != 200) {
        throw ApiException(
          'These notes could not be downloaded. Please try again.',
          status: response.statusCode,
        );
      }
      if (response.bodyBytes.isEmpty ||
          response.bodyBytes.length > 20 * 1024 * 1024) {
        throw const ApiException(
          'This document is empty or too large to open.',
        );
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiException('The download timed out. Please try again.');
    } on http.ClientException {
      throw const ApiException('Cannot download notes. Check your connection.');
    }
  }

  Future<void> logout(String token) async {
    await _request('logout', token: token, post: true);
  }

  void close() => _client.close();
}
