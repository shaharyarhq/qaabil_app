import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/member_api.dart';
import 'member.dart';
import '../models/member_course.dart';
import '../models/objective_resources.dart';
import '../models/video_details.dart';
import '../models/past_papers.dart';
import '../services/note_files.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this.server);
  final String server;
  static const _storage = FlutterSecureStorage();
  String get _key => 'qaabil_member_token_${Uri.encodeComponent(server)}';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Small shared session: no state-management package and no stored password.
class MemberSession extends ChangeNotifier {
  MemberSession({required this.api, TokenStore? store, NoteFiles? noteFiles})
    : _store = store ?? SecureTokenStore(api.baseUrl),
      _noteFiles = noteFiles ?? NoteFiles();
  final MemberApi api;
  final TokenStore _store;
  final NoteFiles _noteFiles;
  Member? member;
  String? _token;
  bool busy = false;
  String? error;
  bool _closed = false;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> restore() async {
    if (!api.configured) return;
    busy = true;
    _notify();
    try {
      _token = await _store.read();
      final token = _token;
      if (token != null) {
        final restoredMember = await api.me(token);
        if (_token == token) member = restoredMember;
      }
    } on ApiException catch (e) {
      error = e.message;
      if (e.status == 401 || e.status == 403) {
        await _store.clear();
        _token = null;
      }
    } catch (_) {
      error = 'Could not restore your session. Please log in again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> login(String email, String password) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      final result = await api.login(email, password);
      try {
        await _store.write(result.token);
      } catch (_) {
        await api.logout(result.token);
        rethrow;
      }
      _token = result.token;
      member = result.member;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Could not securely save your session. Please try again.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final token = _token;
    if (token == null || member == null) {
      throw const ApiException(
        'Please log in to view your learning.',
        status: 401,
      );
    }
    try {
      final result = await request(token);
      if (_token != token) {
        throw const ApiException(
          'Your account changed. Please reload this page.',
        );
      }
      return result;
    } on ApiException catch (e) {
      if (_token == token && (e.status == 401 || e.status == 403)) {
        _token = null;
        member = null;
        error = e.message;
        _notify();
        try {
          await _noteFiles.clear();
          await _store.clear();
        } catch (_) {
          /* Keep private data hidden. */
        }
      }
      rethrow;
    }
  }

  Future<MemberCoursePage> courses({int page = 1}) =>
      _authorized((token) => api.courses(token, page: page));

  Future<PastPaperPage> pastPapers({
    String search = '',
    int? course,
    int? year,
    String? sitting,
    int page = 1,
  }) => _authorized(
    (token) => api.pastPapers(
      token: token,
      search: search,
      course: course,
      year: year,
      sitting: sitting,
      page: page,
    ),
  );

  Future<void> openPaperDocument(int paperId, PaperDocument file) async {
    final token = _token;
    final bytes = await _authorized(
      (token) => api.paperDocument(token, paperId, file),
    );
    await _noteFiles.open(
      file,
      bytes,
      () => _token != null && _token == token && member != null,
    );
  }

  Future<MemberCourse> course(int id) =>
      _authorized((token) => api.course(token, id));

  Future<ObjectiveResources> resources(int objectiveId) =>
      _authorized((token) => api.resources(token, objectiveId));

  Future<VideoPlayback> video(int videoId) =>
      _authorized((token) => api.video(token, videoId));

  Future<VideoDetails> videoDetails(int id) =>
      _authorized((token) => api.videoDetails(token, id));
  Future<VideoReviewPage> videoReviews(int id, {int page = 1}) =>
      _authorized((token) => api.videoReviews(token, id, page: page));
  Future<void> submitVideoReview(int id, int rating, String text) =>
      _authorized((token) => api.submitVideoReview(token, id, rating, text));
  Future<void> deleteVideoReview(int id, int review) =>
      _authorized((token) => api.deleteVideoReview(token, id, review));

  Future<void> openVideoMaterial(int id, VideoMaterial file) async {
    final token = _token;
    final bytes = await _authorized(
      (token) => api.videoMaterial(token, id, file),
    );
    await _noteFiles.open(
      file,
      bytes,
      () => _token != null && _token == token && member != null,
    );
  }

  Future<void> openCurriculumNote(
    String kind,
    int resourceId,
    LessonNote note,
  ) async {
    final token = _token;
    final bytes = await _authorized(
      (token) => api.curriculumNote(token, kind, resourceId, note.id),
    );
    await _noteFiles.open(
      note,
      bytes,
      () => _token != null && _token == token && member != null,
    );
  }

  Future<void> openNote(int objectiveId, LessonNote note) async {
    final token = _token;
    final bytes = await _authorized(
      (token) => api.note(token, objectiveId, note.id),
    );
    await _noteFiles.open(
      note,
      bytes,
      () => _token != null && _token == token && member != null,
    );
  }

  Future<bool> logout() async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      if (_token != null) {
        try {
          await api.logout(_token!);
        } on ApiException catch (e) {
          if (e.status != 401) rethrow;
        }
      }
      await _noteFiles.clear();
      await _store.clear();
      _token = null;
      member = null;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Could not sign out. Please try again.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }
}

class SessionScope extends InheritedNotifier<MemberSession> {
  const SessionScope({
    super.key,
    required MemberSession session,
    required super.child,
  }) : super(notifier: session);
  static MemberSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
