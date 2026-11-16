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
import '../models/video_submission.dart';

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

  Uri _baseUri() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
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
    return uri;
  }

  Uri _uri(String path, {bool public = false}) {
    final base = _baseUri();
    return Uri.parse(
      '${base.toString().replaceFirst(RegExp(r'/+$'), '')}/${public ? '' : 'member/'}$path',
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
          path == 'password/request'
              ? 'Enter a valid email address.'
              : path == 'password/reset'
              ? ((data['errors'] as Map?)?.containsKey('token') == true
                    ? 'This reset code is invalid or expired. Request a new one and try again.'
                    : 'Check your email and password. Use at least 8 characters and confirm your password.')
              : path == 'submissions' || path.startsWith('submissions/')
              ? _submissionValidationMessage(data)
              : path == 'me'
              ? 'Use 120 characters or fewer for each profile field.'
              : path.endsWith('/score')
              ? 'Check the marks allowed for this paper and try again.'
              : path.startsWith('past-papers')
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

  Future<void> requestPasswordReset(String email) async {
    await _request('password/request', post: true, body: {'email': email});
  }

  Future<void> resetPassword(
    String email,
    String code,
    String password,
    String confirmation,
  ) async {
    await _request(
      'password/reset',
      post: true,
      body: {
        'email': email,
        'token': code,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
  }

  Future<Member> me(String token) async {
    return _parseProfile(await _request('me', token: token));
  }

  Future<Member> updateProfile(
    String token,
    String fullName,
    String school,
  ) async {
    return _parseProfile(
      await _request(
        'me',
        token: token,
        post: true,
        body: {'full_name': fullName.trim(), 'school': school.trim()},
      ),
    );
  }

  Member _parseProfile(Map<String, dynamic> data) {
    try {
      return Member.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      throw const ApiException(
        'The member service returned an unexpected response.',
      );
    }
  }

  Future<
    ({
      Map<String, String> languages,
      Map<String, String> focuses,
      int? uploadMaxMb,
    })
  >
  submissionOptions(String token) async {
    final data = await _request('submissions/options', token: token);
    try {
      return (
        languages: Map<String, String>.from(data['languages'] as Map),
        focuses: Map<String, String>.from(data['focuses'] as Map),
        uploadMaxMb: data['upload_max_mb'] as int?,
      );
    } catch (_) {
      throw const ApiException('Could not read the video submission options.');
    }
  }

  Future<bool> submitVideo(String token, Map<String, String> fields) async {
    final data = await _request(
      'submissions',
      token: token,
      post: true,
      body: fields,
    );
    return data['created'] == true;
  }

  Future<bool> uploadVideo(
    String token,
    Map<String, String> fields, {
    required String filename,
    required int size,
    required Stream<List<int>> stream,
    required void Function(double) onProgress,
  }) async {
    var sent = 0;
    final tracked = stream.map((chunk) {
      sent += chunk.length;
      onProgress((sent / size).clamp(0.0, 1.0));
      return chunk;
    });
    final request = http.MultipartRequest('POST', _uri('submissions/upload'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile('file', tracked, size, filename: filename),
      );
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(minutes: 4));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.statusCode == 201;
      }
      final message = switch (response.statusCode) {
        401 => 'Your session has expired. Please log in again.',
        403 => 'Your account cannot submit videos.',
        404 => 'This learning objective is no longer available.',
        409 => 'This file is already being submitted. Try again shortly.',
        413 => 'This file is too large for the server.',
        422 => 'Check the form and choose a supported video file.',
        429 => 'Too many submissions. Please wait a minute and try again.',
        503 => 'Video file uploads are currently unavailable.',
        _ => 'The video could not be uploaded. Please try again.',
      };
      throw ApiException(message, status: response.statusCode);
    } on TimeoutException {
      throw const ApiException('The upload timed out. Please try again.');
    } on http.ClientException {
      throw const ApiException(
        'The upload connection failed. Please try again.',
      );
    } finally {
      client.close();
    }
  }

  String _submissionValidationMessage(Map<String, dynamic> data) {
    final urlErrors = (data['errors'] as Map?)?['video_url'];
    const duplicate = 'You already submitted this video for this objective.';
    if (urlErrors is List && urlErrors.contains(duplicate)) return duplicate;
    if (urlErrors is List) return 'Enter a valid HTTPS YouTube link.';
    return 'Check the required fields and try again.';
  }

  Future<VideoSubmission> submission(String token, int id) async {
    final data = await _request('submissions/$id', token: token);
    try {
      return VideoSubmission.fromJson(data);
    } catch (_) {
      throw const ApiException('Could not read this video submission.');
    }
  }

  Future<void> updateSubmission(
    String token,
    int id,
    Map<String, String> fields,
  ) async {
    await _request('submissions/$id', token: token, post: true, body: fields);
  }

  Future<SubmissionPage> submissions(String token, {int page = 1}) async {
    final data = await _request('submissions?page=$page', token: token);
    try {
      return SubmissionPage.fromJson(data);
    } catch (_) {
      throw const ApiException(
        'Could not read your video submissions. Please try again.',
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

  Future<int> savePaperScore(String token, int paperId, int score) async {
    final response = await _request(
      'past-papers/$paperId/score',
      token: token,
      post: true,
      body: {'score': '$score'},
    );
    final saved = response['score'];
    if (saved is! int) {
      throw const ApiException(
        'Could not confirm your saved marks. Please try again.',
      );
    }
    return saved;
  }

  Future<Uint8List> paperReport(String token, int courseId) =>
      _progressReport(token, 'past-papers/reports/$courseId');

  Future<Uint8List> courseReport(String token, int courseId) =>
      _progressReport(token, 'courses/$courseId/report');

  Future<Uint8List> _progressReport(String token, String path) async {
    final bytes = await _download(
      token,
      path,
      failureMessage:
          'Could not download the progress report. Please try again.',
    );
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const ApiException(
        'The progress report did not arrive as a PDF. Please try again.',
      );
    }
    return bytes;
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

  Future<MemberCoursePage> courses(
    String token, {
    int page = 1,
    String search = '',
  }) async {
    final query = Uri(
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
      },
    ).query;
    final data = await _request('courses?$query', token: token);
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

  Uri courseWebsiteUrl(int id) => _baseUri().replace(path: '/courses/$id');

  Uri quizUrl(String path) {
    if (!RegExp(r'^/member/quiz/[0-9]+/take$').hasMatch(path)) {
      throw const ApiException('This quiz link is unavailable.');
    }
    return _baseUri().replace(path: path);
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

  Future<Uint8List> _download(
    String token,
    String path, {
    String failureMessage =
        'These notes could not be downloaded. Please try again.',
  }) async {
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
        throw ApiException(failureMessage, status: response.statusCode);
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
      throw const ApiException(
        'Cannot download the file. Check your connection.',
      );
    }
  }

  Future<void> logout(String token) async {
    await _request('logout', token: token, post: true);
  }

  void close() => _client.close();
}
