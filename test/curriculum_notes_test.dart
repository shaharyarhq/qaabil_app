import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'quiz_path': '/member/quiz/20/take',
      'notes': [_note('Section guide.pdf')],
      'chapters': [
        {
          'id': 30,
          'name': 'First chapter',
          'quiz_path': '/member/quiz/30/take',
          'notes': [_note('Chapter guide.pdf')],
          'objectives': [
            {
              'id': 40,
              'name': 'Learning objective',
              'status': 'practice',
              'quiz_path': '/member/quiz/40/take',
            },
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
  VoidCallback? onFileOpened,
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
      if (request.url.path.endsWith('/objectives/40/resources')) {
        return _json({
          'data': {
            'objective': {'name': 'Learning objective'},
            'videos': [],
            'notes': [_note('Objective guide.pdf')],
          },
        });
      }
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
        onFileOpened?.call();
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
      late Completer<void> fileOpened;
      await _open(
        tester,
        (request) async {
          paths.add(request.url.path);
          return http.Response('%PDF-1.4 notes', 200);
        },
        opened,
        onFileOpened: () => fileOpened.complete(),
      );
      expect(find.text('Learn from the course materials.'), findsOneWidget);
      for (final name in [
        'Course notes',
        'Download objective notes',
        'Download chapter notes',
        'Download section notes',
      ]) {
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          fileOpened = Completer<void>();
          await tester.tap(find.text(name));
          await fileOpened.future.timeout(const Duration(seconds: 5));
        });
        await tester.pumpAndSettle();
      }
      expect(paths, [
        '/api/v1/member/learning-notes/course/18/1',
        '/api/v1/member/objectives/40/notes/1',
        '/api/v1/member/learning-notes/chapter/30/1',
        '/api/v1/member/learning-notes/section/20/1',
      ]);
      expect(opened.length, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Course footer actions stack on phones and group on tablets', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = tester.binding.defaultBinaryMessenger;
    final launches = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      launches.add(call.arguments['url'] as String);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await _open(
      tester,
      (_) async => throw StateError('Unexpected download'),
      [],
    );

    final labels = [
      ('Download objective notes', 'Take Quiz'),
      ('Download chapter notes', 'Take Chapter test'),
      ('Download section notes', 'Take Section Exam'),
    ];
    for (final (notesLabel, quizLabel) in labels) {
      final notes = find.widgetWithText(OutlinedButton, notesLabel);
      final quiz = find.widgetWithText(FilledButton, quizLabel);
      expect(
        tester.getRect(notes).width,
        closeTo(tester.getRect(quiz).width, 1),
      );
      expect(
        tester.getBottomLeft(notes).dy,
        lessThanOrEqualTo(tester.getTopLeft(quiz).dy),
      );
      await tester.ensureVisible(quiz);
      await tester.pumpAndSettle();
      await tester.tap(quiz);
      await tester.pumpAndSettle();
    }
    expect(launches, [
      'https://example.test/member/quiz/40/take',
      'https://example.test/member/quiz/30/take',
      'https://example.test/member/quiz/20/take',
    ]);

    tester.view.physicalSize = const Size(800, 1200);
    await tester.pumpAndSettle();
    for (final (notesLabel, quizLabel) in labels) {
      final notes = find.widgetWithText(OutlinedButton, notesLabel);
      final quiz = find.widgetWithText(FilledButton, quizLabel);
      expect(tester.getCenter(notes).dy, closeTo(tester.getCenter(quiz).dy, 1));
      expect(
        tester.getTopRight(notes).dx,
        lessThan(tester.getTopLeft(quiz).dx),
      );
    }

    final section = find.text('First section');
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    await tester.tap(section);
    await tester.pumpAndSettle();
    expect(find.text('Take Chapter test'), findsNothing);
    expect(find.text('Take Section Exam'), findsOneWidget);
  });

  testWidgets('Failed document can be retried without losing the course', (
    tester,
  ) async {
    var attempts = 0;
    final opened = <String>[];
    late Completer<void> fileOpened;
    await _open(
      tester,
      (_) async => ++attempts == 1
          ? _json({}, 404)
          : http.Response('%PDF-1.4 notes', 200),
      opened,
      onFileOpened: () => fileOpened.complete(),
    );
    await tester.ensureVisible(find.text('Course notes'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Course notes'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('These notes could not be downloaded. Please try again.'),
      findsOneWidget,
    );
    expect(opened, isEmpty);
    await tester.runAsync(() async {
      fileOpened = Completer<void>();
      await tester.tap(find.text('Course notes'));
      await fileOpened.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    expect(opened.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Course hero opens the authenticated course progress PDF', (
    tester,
  ) async {
    final opened = <String>[];
    final requests = <String>[];
    late Completer<void> fileOpened;
    await _open(
      tester,
      (request) async {
        requests.add(request.url.path);
        return http.Response('%PDF-1.4 notes', 200);
      },
      opened,
      onFileOpened: () => fileOpened.complete(),
    );
    final report = find.text('Progress Report');
    await tester.ensureVisible(report);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      fileOpened = Completer<void>();
      await tester.tap(report);
      await fileOpened.future.timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    expect(requests, ['/api/v1/member/courses/18/report']);
    expect(opened.single, endsWith('.pdf'));
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
    expect(find.text('Course notes'), findsNothing);
    expect(find.text('Download section notes'), findsNothing);
    expect(find.text('Download chapter notes'), findsNothing);
    expect(find.text('Take Section Exam'), findsNothing);
    expect(find.text('Login for videos & notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
