import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/models/objective_resources.dart';
import 'package:qaabil_mobile/screens/objective_resources_screen.dart';
import 'package:qaabil_mobile/services/member_api.dart';
import 'package:qaabil_mobile/services/note_files.dart';
import 'package:qaabil_mobile/widgets/objective_video_preview.dart';

class _Store implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Future<void> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = MemberApi(
    baseUrl: 'https://example.test/api/v1',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return _json({
          'token': 'token',
          'user': {'id': 1, 'name': 'Student', 'email': 'student@example.test'},
        });
      }
      expect(request.headers['Authorization'], 'Bearer token');
      return handler(request);
    }),
  );
  final session = MemberSession(api: api, store: _Store());
  await session.login('student@example.test', 'password');
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: const MaterialApp(home: ObjectiveResourcesScreen(objectiveId: 3)),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
}

void main() {
  testWidgets(
    'Objective lists real videos and notes and handles a playback lock without logout',
    (tester) async {
      await _open(tester, (request) async {
        if (request.url.path.endsWith('/videos/8')) {
          return _json({
            'data': {
              'title': 'Accounting basics',
              'creator': 'Tutor',
              'youtube_id': null,
              'access': {'allowed': false, 'reason': 'playback_setup_pending'},
            },
          });
        }
        return _json({
          'data': {
            'objective': {'name': 'Double entry'},
            'videos': [
              {
                'id': 8,
                'title': 'Accounting basics',
                'creator': 'Tutor',
                'thumbnail': null,
              },
            ],
            'notes': [
              {
                'id': 0,
                'name': 'lesson.pdf',
                'size': 1024,
                'mime': 'application/pdf',
              },
            ],
          },
        });
      });
      expect(find.text('Accounting basics'), findsOneWidget);
      expect(find.text('lesson.pdf'), findsOneWidget);
      final card = find.byType(ObjectiveVideoCard);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(
        find.text('Playback is not available in this build yet.'),
        findsOneWidget,
      );
      expect(find.text('Log in again to watch this video.'), findsNothing);
    },
  );

  testWidgets('Objective filters combine and videos sort in the tablet grid', (
    tester,
  ) async {
    await _open(
      tester,
      (_) async => _json({
        'data': {
          'objective': {'name': 'Double entry'},
          'videos': [
            {
              'id': 8,
              'title': 'Accounting basics',
              'creator': 'Tutor A',
              'creator_id': 1,
              'language': 'English',
              'focus': 'lesson_focused',
              'submitted_at': '2026-11-01T00:00:00Z',
              'average_rating': 4.5,
              'review_count': 2,
            },
            {
              'id': 9,
              'title': 'Practice exercises',
              'creator': 'Tutor B',
              'creator_id': 2,
              'language': 'Urdu',
              'focus': 'question_focused',
              'submitted_at': '2026-11-02T00:00:00Z',
            },
          ],
          'notes': [
            {
              'id': 0,
              'name': 'lesson.pdf',
              'size': 1024,
              'mime': 'application/pdf',
            },
          ],
        },
      }),
    );
    tester.view.physicalSize = const Size(1280, 820);
    await tester.pumpAndSettle();
    expect(find.text('4.5 (2)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Accounting basics')).dy,
      tester.getTopLeft(find.text('Practice exercises')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Accounting basics')).dx,
      greaterThan(tester.getTopLeft(find.text('Practice exercises')).dx),
    );

    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highest rating first').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Practice exercises')).dx,
      greaterThan(tester.getTopLeft(find.text('Accounting basics')).dx),
    );

    await tester.tap(find.byTooltip('All focus types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Question Focused').last);
    await tester.pumpAndSettle();
    expect(find.text('Accounting basics'), findsNothing);
    expect(find.text('Practice exercises'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tutor a');
    await tester.pumpAndSettle();
    expect(find.text('Accounting basics'), findsOneWidget);
    expect(find.text('Practice exercises'), findsNothing);

    await tester.tap(find.byTooltip('All languages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urdu').last);
    await tester.pumpAndSettle();
    expect(
      find.text('No videos match your search or filters.'),
      findsOneWidget,
    );
    expect(find.text('lesson.pdf'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('All creators'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutor B').last);
    await tester.pumpAndSettle();
    expect(find.text('Accounting basics'), findsNothing);
    expect(find.text('Practice exercises'), findsOneWidget);
  });

  testWidgets('Objective empty resources and retry states are explicit', (
    tester,
  ) async {
    var calls = 0;
    await _open(tester, (_) async {
      if (calls++ == 0) return _json({}, 503);
      return _json({
        'data': {
          'objective': {'name': 'Double entry'},
          'videos': [],
          'notes': [],
        },
      });
    });
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No approved videos are available yet.'), findsOneWidget);
    expect(find.text('No notes have been added yet.'), findsOneWidget);
  });

  test(
    'Note bytes use bearer authentication, never token query parameters',
    () async {
      final api = MemberApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/member/objectives/3/notes/0');
          expect(request.url.query, isEmpty);
          expect(request.headers['Authorization'], 'Bearer token');
          return http.Response.bytes([37, 80, 68, 70], 200);
        }),
      );
      expect(await api.note('token', 3, 0), [37, 80, 68, 70]);
      api.close();
    },
  );

  test('Playback never accepts an invalid or locked YouTube ID', () {
    expect(
      VideoPlayback.fromJson({
        'title': 'Video',
        'access': {'allowed': true},
        'youtube_id': 'bad',
      }).allowed,
      isFalse,
    );
    expect(
      VideoPlayback.fromJson({
        'title': 'Video',
        'access': {'allowed': true},
        'youtube_id': 'eNEgvVJI_zw',
      }).allowed,
      isTrue,
    );
    expect(
      VideoPlayback.fromJson({
        'title': 'Video',
        'access': {'allowed': false},
        'youtube_id': 'eNEgvVJI_zw',
      }).youtubeId,
      isNull,
    );
  });

  test('Temporary notes use generated filenames and can be removed', () async {
    final root = await Directory.systemTemp.createTemp('qaabil-note-test');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    String? opened;
    final files = NoteFiles(
      directory: () async => Directory('${root.path}/private'),
      openFile: (path, mime) async {
        opened = path;
        expect(mime, 'application/pdf');
        expect(await File(path).readAsBytes(), [37, 80, 68, 70]);
        return OpenResult();
      },
    );
    await files.open(
      const LessonNote(
        id: 0,
        name: '../../lesson.pdf',
        size: 4,
        mime: 'application/pdf',
      ),
      Uint8List.fromList([37, 80, 68, 70]),
      () => true,
    );
    expect(opened, startsWith('${root.path}/private/'));
    expect(opened, isNot(contains('lesson')));
    await files.clear();
    expect(await File(opened!).exists(), isFalse);
  });

  test(
    'A signed-out member cannot dispatch a downloaded file to another app',
    () async {
      final files = NoteFiles(
        openFile: (_, mime) async {
          fail('Must not open a file after sign-out');
        },
      );
      await expectLater(
        files.open(
          const LessonNote(
            id: 0,
            name: 'lesson.pdf',
            size: 4,
            mime: 'application/pdf',
          ),
          Uint8List.fromList([37, 80, 68, 70]),
          () => false,
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
