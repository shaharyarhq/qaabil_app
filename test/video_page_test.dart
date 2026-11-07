import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/models/video_details.dart';
import 'package:qaabil_mobile/screens/lesson_video_screen.dart';
import 'package:qaabil_mobile/services/member_api.dart';

class _Store implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

http.Response _json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
Map<String, dynamic> _details({bool materials = false}) => {
  'description': 'Existing lesson description',
  'status': 'approved',
  'language': 'en',
  'submitted_at': '2026-11-01T10:00:00Z',
  'approved_by': 'Reviewer name',
  'course': {'id': 14, 'name': 'Real Course'},
  'section': {'id': 19, 'name': 'Real Section'},
  'chapter': {'id': 26, 'name': 'Real Chapter'},
  'objective': {'id': 34, 'name': 'Real Objective'},
  'materials': materials
      ? [
          {
            'id': 0,
            'name': 'real.pdf',
            'mime': 'application/pdf',
            'size': 1024,
            'kind': 'learning_materials',
          },
          {
            'id': 0,
            'name': 'notes.png',
            'mime': 'image/png',
            'size': 2048,
            'kind': 'quiz_attachments',
          },
        ]
      : [],
  'quiz_url': materials ? 'https://qaabil.io/practice/example' : null,
  'related_total': 1,
  'related': [
    {
      'id': 9,
      'title': 'Related approved lesson',
      'creator': 'Another member',
      'thumbnail': null,
    },
  ],
};
Map<String, dynamic> _review({int id = 5, bool mine = false}) => {
  'id': id,
  'author': mine ? 'Student' : 'Website member',
  'review': mine ? 'Useful lesson' : 'Existing web review',
  'rating': 4,
  'created_at': '2026-11-01T10:00:00Z',
  'is_mine': mine,
};
Map<String, dynamic> _reviews({
  Map<String, dynamic>? own,
  List<Map<String, dynamic>>? rows,
  int page = 1,
  int last = 1,
}) => {
  'data': rows ?? (own == null ? [] : [own]),
  'own_review': own,
  'summary': {
    'total': own == null && rows == null ? 0 : 2,
    'average': 4,
    'counts': [0, 0, 0, 2, 0],
  },
  'meta': {'current_page': page, 'last_page': last},
};

Future<MemberSession> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  bool materials = false,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = MemberApi(
    baseUrl: 'https://example.test/api/v1',
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login')) {
        return _json({
          'token': 'test-token',
          'user': {'id': 1, 'name': 'Student', 'email': 'student@example.test'},
        });
      }
      expect(r.headers['Authorization'], 'Bearer test-token');
      if (r.url.path.endsWith('/logout')) return _json({});
      if (r.url.path.endsWith('/videos/8')) {
        return _json({
          'data': {
            'title': 'Actual video',
            'creator': 'Tutor',
            'access': {'allowed': false},
            'youtube_id': null,
          },
        });
      }
      if (r.url.path.endsWith('/details')) {
        return _json({'data': _details(materials: materials)});
      }
      return handler(r);
    }),
  );
  final session = MemberSession(api: api, store: _Store());
  await session.login('student@example.test', 'test-password');
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: const MaterialApp(home: LessonVideoScreen(videoId: 8)),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
  return session;
}

Future<void> _tab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Overview shows real context and related submissions; tabs preserve the player',
    (tester) async {
      await _open(tester, (_) async => _json(_reviews()));
      expect(find.widgetWithText(ChoiceChip, 'Materials'), findsNothing);
      expect(find.text('Existing lesson description'), findsOneWidget);
      expect(find.text('Approved by: Reviewer name'), findsOneWidget);
      expect(find.text('Chapter: Real Chapter'), findsOneWidget);
      expect(find.text('Related approved lesson'), findsOneWidget);
      await _tab(tester, 'Reviews');
      expect(
        find.text('No reviews yet. Be the first to share your thoughts.'),
        findsOneWidget,
      );
      await _tab(tester, 'Overview');
      expect(find.text('Actual video'), findsOneWidget);
      expect(find.text('Existing lesson description'), findsOneWidget);
    },
  );

  testWidgets(
    'Member submits a review and can cancel or confirm deleting only their review',
    (tester) async {
      Map<String, dynamic>? own;
      var deletes = 0;
      await _open(tester, (r) async {
        if (r.method == 'POST') {
          expect(r.bodyFields, {'rating': '5', 'review': 'Useful lesson'});
          own = {..._review(mine: true), 'rating': 5};
          return _json({'id': 5}, 201);
        }
        if (r.method == 'DELETE') {
          expect(r.url.path.endsWith('/8/reviews/5'), isTrue);
          own = null;
          deletes++;
          return _json({});
        }
        return _json(_reviews(own: own));
      });
      await _tab(tester, 'Reviews');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit review'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('5 stars'));
      await tester.enterText(find.byType(TextField), 'Useful lesson');
      await tester.ensureVisible(find.text('Submit review'));
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();
      expect(
        find.text('You have already reviewed this video.'),
        findsOneWidget,
      );
      expect(find.text('Useful lesson'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete my review'));
      await tester.tap(find.text('Delete my review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.text('Delete my review'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete review'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Submit review'), findsOneWidget);
    },
  );

  testWidgets(
    'Review request can retry and append another page without duplicating entries',
    (tester) async {
      var fail = true;
      await _open(tester, (r) async {
        if (fail) return _json({}, 503);
        final next = r.url.queryParameters['page'] == '2';
        return _json(
          _reviews(
            rows: [_review(id: next ? 6 : 5)],
            page: next ? 2 : 1,
            last: 2,
          ),
        );
      });
      await _tab(tester, 'Reviews');
      expect(find.text('Retry reviews'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry reviews'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Load more reviews'));
      await tester.tap(find.text('Load more reviews'));
      await tester.pumpAndSettle();
      expect(find.text('Existing web review'), findsNWidgets(2));
      expect(find.text('Load more reviews'), findsNothing);
      expect(find.text('Delete my review'), findsNothing);
    },
  );

  testWidgets(
    'Materials keep video attachments distinct from notes and expose configured quiz links',
    (tester) async {
      await _open(tester, (_) async => _json(_reviews()), materials: true);
      await _tab(tester, 'Materials');
      expect(find.text('real.pdf'), findsOneWidget);
      expect(find.text('notes.png'), findsOneWidget);
      expect(find.text('Learning material · 1 KB'), findsOneWidget);
      expect(find.text('Video notes · 2 KB'), findsOneWidget);
      expect(find.text('Open quiz'), findsOneWidget);
    },
  );

  testWidgets(
    'A late review response cannot show private content after sign-out',
    (tester) async {
      final pending = Completer<http.Response>();
      final session = await _open(tester, (_) => pending.future);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Reviews'));
      await tester.pump();
      await session.logout();
      await tester.pumpAndSettle();
      pending.complete(_json(_reviews(rows: [_review()])));
      await tester.pumpAndSettle();
      expect(find.text('Log in again to watch this video.'), findsOneWidget);
      expect(find.text('Existing web review'), findsNothing);
    },
  );

  test('Material download uses scoped bearer authentication and no token in its URL', () async {
    final api = MemberApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((r) async {
        expect(
          r.url.path,
          '/api/v1/member/videos/8/materials/learning_materials/0',
        );
        expect(r.url.query, isEmpty);
        expect(r.headers['Authorization'], 'Bearer token');
        return http.Response.bytes([37, 80, 68, 70], 200);
      }),
    );
    expect(
      await api.videoMaterial(
        'token',
        8,
        const VideoMaterial(
          id: 0,
          name: 'lesson.pdf',
          size: 4,
          mime: 'application/pdf',
          kind: 'learning_materials',
        ),
      ),
      [37, 80, 68, 70],
    );
    api.close();
  });

  test('Unsafe quiz protocols are not exposed as openable links', () {
    expect(
      VideoDetails.fromJson({..._details(), 'quiz_url': 'javascript:alert(1)'})
          .quizUrl,
      isNull,
    );
    expect(
      VideoDetails.fromJson({
        ..._details(),
        'quiz_url': 'https://user:pass@example.test/quiz',
      }).quizUrl,
      isNull,
    );
  });
}
