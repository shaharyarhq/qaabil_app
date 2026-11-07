import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/models/objective_resources.dart';
import 'package:qaabil_mobile/screens/past_papers_screen.dart';
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

class _Files extends NoteFiles {
  final opened = <String>[];
  @override
  Future<void> open(
    LessonNote note,
    Uint8List bytes,
    bool Function() stillSignedIn,
  ) async {
    expect(stillSignedIn(), isTrue);
    expect(utf8.decode(bytes), '%PDF-1.4 paper');
    opened.add(note.name);
  }
}

Map<String, dynamic> _paper({int id = 8, String name = 'Paper 12'}) => {
  'id': id,
  'paper_name': name,
  'course': {'id': 14, 'name': 'Accounting'},
  'year': 2025,
  'sitting': 'May/June',
  'other_details': 'Variant 2',
  'total_marks': 80,
  'documents': [
    for (final kind in ['question_paper', 'marking_scheme', 'examiners_report'])
      {
        'id': 0,
        'kind': kind,
        'name': '$kind.pdf',
        'size': 2048,
        'mime': 'application/pdf',
      },
  ],
};
Map<String, dynamic> _page({
  List<Map<String, dynamic>>? papers,
  int page = 1,
  int last = 1,
}) => {
  'data': papers ?? [_paper()],
  'meta': {
    'current_page': page,
    'last_page': last,
    'total': last > 1 ? 2 : (papers ?? [_paper()]).length,
  },
  'filters': {
    'courses': [
      {'id': 14, 'name': 'Accounting'},
    ],
    'years': [2025, 2024],
    'sittings': ['May/June', 'October/November'],
  },
};
http.Response _json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
Future<MemberSession> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
  _Files? files,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = MemberApi(
    baseUrl: 'https://example.test/api/v1',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return _json({
          'token': 'token',
          'user': {'id': 1, 'name': 'Member', 'email': 'member@example.test'},
        });
      }
      if (request.url.path.endsWith('/logout')) return _json({});
      expect(request.headers['Authorization'], 'Bearer token');
      return handler(request);
    }),
  );
  final session = MemberSession(
    api: api,
    store: _Store(),
    noteFiles: files ?? _Files(),
  );
  if (signedIn) await session.login('member@example.test', 'password');
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: MaterialApp(
        theme: AppTheme.light,
        home: PastPapersScreen(onBrowseCourses: () {}),
      ),
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

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(target.first),
    alignment: 0.4,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Real paper metadata and all three document kinds open with member authorization',
    (tester) async {
      final paths = <String>[];
      final files = _Files();
      await _open(tester, (request) async {
        if (request.url.path.endsWith('/past-papers')) return _json(_page());
        expect(request.url.queryParameters, isEmpty);
        paths.add(request.url.path);
        return http.Response('%PDF-1.4 paper', 200);
      }, files: files);
      expect(find.text('Paper 12'), findsOneWidget);
      expect(find.text('Variant 2'), findsOneWidget);
      for (final label in [
        'Question paper',
        'Marking scheme',
        'Examiner’s report',
      ]) {
        await _tap(tester, label);
      }
      expect(paths, [
        for (final kind in [
          'question_paper',
          'marking_scheme',
          'examiners_report',
        ])
          '/api/v1/member/past-papers/8/files/$kind',
      ]);
      expect(files.opened.length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Course year sitting and debounced paper name are sent together; clear resets them',
    (tester) async {
      final queries = <Map<String, String>>[];
      await _open(tester, (request) async {
        queries.add(request.url.queryParameters);
        return _json(_page());
      });
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounting').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2024').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('October/November').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Paper 2');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(queries.last, {
        'course': '14',
        'year': '2024',
        'sitting': 'October/November',
        'search': 'Paper 2',
        'page': '1',
      });
      await _tap(tester, 'Clear filters');
      expect(queries.last, {'page': '1'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('List retry and pagination keep previously loaded papers', (
    tester,
  ) async {
    var calls = 0;
    await _open(tester, (request) async {
      if (++calls == 1) return _json({}, 503);
      if (request.url.queryParameters['page'] == '2') {
        return _json(
          _page(papers: [_paper(id: 9, name: 'Paper 22')], page: 2, last: 2),
        );
      }
      return _json(_page(last: 2));
    });
    await _tap(tester, 'Retry');
    await _tap(tester, 'Load more papers');
    expect(find.text('Paper 12'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Paper 22'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paper 22'), findsOneWidget);
    expect(find.text('Load more papers'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guests do not request papers; empty member results are honest', (
    tester,
  ) async {
    await _open(
      tester,
      (_) async => throw StateError('No guest request'),
      signedIn: false,
    );
    expect(find.text('Login to your account'), findsOneWidget);
    expect(find.text('Paper 12'), findsNothing);
  });

  testWidgets('Empty results and failed file downloads can be retried', (
    tester,
  ) async {
    var downloads = 0;
    final files = _Files();
    await _open(tester, (request) async {
      if (request.url.path.endsWith('/past-papers')) {
        return _json(
          _page(
            papers: request.url.queryParameters.containsKey('search')
                ? []
                : null,
          ),
        );
      }
      return ++downloads == 1
          ? _json({}, 404)
          : http.Response('%PDF-1.4 paper', 200);
    }, files: files);
    await _tap(tester, 'Question paper');
    expect(
      find.text('These notes could not be downloaded. Please try again.'),
      findsOneWidget,
    );
    await _tap(tester, 'Question paper');
    expect(files.opened.length, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'No matching paper');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No matching papers'), findsOneWidget);
    await _tap(tester, 'Show all papers');
    expect(find.text('Paper 12'), findsOneWidget);
  });

  testWidgets(
    'A late search result cannot replace a newer filter or repopulate after logout',
    (tester) async {
      final old = Completer<http.Response>();
      final session = await _open(tester, (request) async {
        if (request.url.queryParameters['search'] == 'Old') return old.future;
        return _json(
          _page(
            papers: [
              _paper(
                name: request.url.queryParameters['search'] == 'New'
                    ? 'New result'
                    : 'Initial paper',
              ),
            ],
          ),
        );
      });
      await tester.enterText(find.byType(TextField), 'Old');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'New');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsOneWidget);
      old.complete(_json(_page(papers: [_paper(name: 'Old result')])));
      await tester.pumpAndSettle();
      expect(find.text('Old result'), findsNothing);
      await session.logout();
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsNothing);
      expect(find.text('Login to your account'), findsOneWidget);
    },
  );
}
