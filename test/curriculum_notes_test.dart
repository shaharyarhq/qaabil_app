import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/screens/member_course_screen.dart';
import 'package:qaabil_mobile/services/member_api.dart';
import 'package:qaabil_mobile/services/note_files.dart';
import 'package:qaabil_mobile/theme/app_theme.dart';

class _Store implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

Map<String, Object> _note(String name) => {
  'id': 1,
  'name': name,
  'size': 14,
  'mime': 'application/pdf',
};
final _course = {
  'id': 18,
  'name': 'Real course',
  'description': 'Learn from the course materials.',
  'notes': [_note('Course guide.pdf')],
  'sections': [
    {
      'id': 20,
      'name': 'First section',
      'notes': [_note('Section guide.pdf')],
      'chapters': [
        {
          'id': 30,
          'name': 'First chapter',
          'notes': [_note('Chapter guide.pdf')],
          'objectives': [
            {'id': 40, 'name': 'Learning objective', 'status': 'practice'},
          ],
        },
      ],
    },
  ],
};
http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Future<MemberSession> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) download,
  List<String> opened, {
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final folder = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('qaabil-curriculum-test-'),
  ))!;
  final api = MemberApi(
    baseUrl: 'https://example.test/api/v1',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return _json({
          'token': 'token',
          'user': {'id': 1, 'name': 'Member', 'email': 'member@example.test'},
        });
      }
      if (request.url.path.endsWith('/courses/18')) {
        return _json({'data': _course});
      }
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.url.queryParameters, isEmpty);
      return download(request);
    }),
  );
  final session = MemberSession(
    api: api,
    store: _Store(),
    noteFiles: NoteFiles(
      directory: () async => folder,
      openFile: (path, mime) async {
        expect(mime, 'application/pdf');
        expect(await File(path).readAsString(), '%PDF-1.4 notes');
        opened.add(path);
        return OpenResult(type: ResultType.done);
      },
    ),
  );
  if (signedIn) await session.login('member@example.test', 'password');
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MemberCourseScreen(courseId: 18),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
    await tester.runAsync(() async {
      if (await folder.exists()) await folder.delete(recursive: true);
    });
  });
  return session;
}

void main() {
  testWidgets(
    'Each level opens its own authenticated backend attachment on a phone',
    (tester) async {
      final paths = <String>[];
      final opened = <String>[];
      await _open(tester, (request) async {
        paths.add(request.url.path);
        return http.Response('%PDF-1.4 notes', 200);
      }, opened);
      expect(find.text('Learn from the course materials.'), findsOneWidget);
      for (final name in ['Course guide.pdf', 'Section guide.pdf']) {
        await tester.ensureVisible(find.text(name));
        await tester.runAsync(() async {
          await tester.tap(find.text(name));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('First chapter'));
      await tester.tap(find.text('First chapter'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Chapter guide.pdf')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Chapter guide.pdf'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(paths, [
        '/api/v1/member/learning-notes/course/18/1',
        '/api/v1/member/learning-notes/section/20/1',
        '/api/v1/member/learning-notes/chapter/30/1',
      ]);
      expect(opened.length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed document can be retried without losing the course', (
    tester,
  ) async {
    var attempts = 0;
    final opened = <String>[];
    await _open(
      tester,
      (_) async => ++attempts == 1
          ? _json({}, 404)
          : http.Response('%PDF-1.4 notes', 200),
      opened,
    );
    await tester.ensureVisible(find.text('Course guide.pdf'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Course guide.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('These notes could not be downloaded. Please try again.'),
      findsOneWidget,
    );
    expect(opened, isEmpty);
    await tester.runAsync(() async {
      await tester.tap(find.text('Course guide.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(opened.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guest course content never exposes member note buttons', (
    tester,
  ) async {
    await _open(
      tester,
      (_) async => throw StateError('No guest download'),
      [],
      signedIn: false,
    );
    expect(find.text('Course guide.pdf'), findsNothing);
    expect(find.text('Section guide.pdf'), findsNothing);
    await tester.ensureVisible(find.text('First chapter'));
    await tester.tap(find.text('First chapter'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter guide.pdf'), findsNothing);
    expect(find.text('Login for videos & notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
