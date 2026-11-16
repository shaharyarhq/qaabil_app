import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/main.dart';
import 'package:qaabil_mobile/services/member_api.dart';

import 'support/public_catalogue.dart';

class _TokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

const _user = {'id': 3, 'name': 'Student', 'email': 'student@example.test'};
const _progress = {
  'total': 5,
  'started': 3,
  'not_started': 2,
  'behind': 1,
  'practice': 1,
  'mastery': 1,
  'coverage_percent': 60,
  'mastery_percent': 20,
};
Map<String, dynamic> _course({int id = 41, String name = 'Real Accounting'}) =>
    {
      'id': id,
      'name': name,
      'qualification': 'Cambridge IGCSE',
      'progress': _progress,
    };
Map<String, dynamic> _page({
  List<Map<String, dynamic>>? courses,
  int page = 1,
  int last = 1,
}) => {
  'data': courses ?? [_course()],
  'meta': {'current_page': page, 'last_page': last, 'total': 2},
};
http.Response _json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

Future<MemberSession> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) respond,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = MemberApi(
    baseUrl: 'https://example.test/api/v1',
    client: MockClient((request) async {
      final public = defaultPublicResponse(request);
      if (public != null) return public;
      if (request.url.path.endsWith('/login')) {
        return _json({'token': 'token', 'user': _user});
      }
      if (request.url.path.endsWith('/me')) return _json({'user': _user});
      if (request.url.path.endsWith('/logout')) return _json({});
      expectSync(request.headers['Authorization'], 'Bearer token');
      return respond(request);
    }),
  );
  final session = MemberSession(api: api, store: _TokenStore());
  await session.login('student@example.test', 'password');
  await tester.pumpWidget(QaabilApp(session: session));
  await tester.pumpAndSettle();
  await tester.tap(find.text('My Learning'));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
  return session;
}

Finder _statusMarker(String status) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == status,
);

void main() {
  testWidgets(
    'Member overview shows real dates, progress and course structure',
    (tester) async {
      await _open(tester, (request) async {
        if (!request.url.path.endsWith('/courses/41')) return _json(_page());
        return _json({
          'data': {
            ..._course(),
            'created_at': '2026-01-12T12:00:00Z',
            'updated_at': '2026-02-15T12:00:00Z',
            'sections': [
              {
                'id': 1,
                'name': 'Accounting essentials',
                'chapters': [
                  {
                    'id': 2,
                    'name': 'Double entry',
                    'objectives': [
                      {
                        'id': 3,
                        'name': 'Prepare a ledger',
                        'status': 'mastery',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        });
      });
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      final overviewTitle = find.text('View Real Accounting');
      expect(
        Theme.of(tester.element(overviewTitle)).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(overviewTitle)).brightness,
        Brightness.light,
      );
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Last updated'), findsOneWidget);
      expect(find.text('Unavailable'), findsNothing);
      expect(find.text('View Real Accounting'), findsOneWidget);
      expect(find.text('Download Report'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('3 of 5 objectives marked'),
        250,
      );
      expect(find.text('3 of 5 objectives marked'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Learning Objectives — RAG'),
        250,
      );
      final mastery = find.widgetWithText(TextButton, 'Mastery Reached');
      await tester.ensureVisible(mastery);
      await tester.pumpAndSettle();
      await tester.tap(mastery);
      await tester.pumpAndSettle();
      expect(find.text('Marked'), findsNothing);
      await tester.tap(mastery);
      await tester.pumpAndSettle();
      expect(find.text('Marked'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Double entry'), 250);
      await tester.tap(find.text('Double entry'));
      await tester.pumpAndSettle();
      expect(find.text('Prepare a ledger'), findsOneWidget);

      tester.view.physicalSize = const Size(1100, 900);
      await tester.pumpAndSettle();
      final summary = find.text('My Progress');
      await tester.scrollUntilVisible(summary, -250);
      final chart = find.text('Learning Objectives — RAG');
      await tester.scrollUntilVisible(chart, 200);
      expect(
        tester.getTopLeft(chart).dy,
        greaterThan(tester.getTopLeft(summary).dy),
      );
      expect(tester.getTopLeft(chart).dx, tester.getTopLeft(summary).dx);
      final openContent = find.text('Open course content');
      await tester.scrollUntilVisible(openContent, 250);
      await tester.tap(openContent);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An objective quiz opens the member site and refreshes progress on return',
    (tester) async {
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger = tester.binding.defaultBinaryMessenger;
      final launches = <MethodCall>[];
      messenger.setMockMethodCallHandler(launcher, (call) async {
        launches.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
      var graded = false;
      var courseRequests = 0;
      await _open(tester, (request) async {
        if (request.url.path.endsWith('/courses/41')) {
          courseRequests++;
          return _json({
            'data': {
              ..._course(),
              'progress': {..._progress, 'mastery_percent': graded ? 40 : 20},
              'sections': [
                {
                  'id': 1,
                  'name': 'Section',
                  'chapters': [
                    {
                      'id': 2,
                      'name': 'Quiz chapter',
                      'objectives': [
                        {
                          'id': 3,
                          'name': 'Quiz objective',
                          'status': graded ? 'mastery' : 'practice',
                          'quiz_path': '/member/quiz/61/take',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          });
        }
        if (request.url.path.endsWith('/objectives/3/resources')) {
          return _json({
            'data': {
              'objective': {'name': 'Quiz objective'},
              'videos': [],
              'notes': [],
            },
          });
        }
        return _json(
          _page(
            courses: [
              {
                ..._course(),
                'progress': {..._progress, 'mastery_percent': graded ? 40 : 20},
              },
            ],
          ),
        );
      });
      await tester.tap(find.text('Open course'));
      await tester.pumpAndSettle();
      expect(_statusMarker('Practice'), findsOneWidget);
      final quiz = find.text('Take Quiz');
      await tester.ensureVisible(quiz);
      await tester.pumpAndSettle();
      await tester.tap(quiz);
      await tester.pumpAndSettle();
      expect(launches.single.method, 'launch');
      expect(
        launches.single.arguments['url'],
        'https://example.test/member/quiz/61/take',
      );

      graded = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(courseRequests, 2);
      expect(_statusMarker('Mastery'), findsOneWidget);
      expect(find.textContaining('40% mastered'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Real Accounting'), findsOneWidget);
      expect(find.textContaining('40% mastered'), findsOneWidget);
    },
  );

  testWidgets(
    'Opening a chapter shows rated video cards alongside objective progress',
    (tester) async {
      var previewRequests = 0;
      await _open(tester, (request) async {
        if (request.url.path.endsWith('/objectives/3/resources')) {
          previewRequests++;
          return _json({
            'data': {
              'objective': {'name': 'Explain accounting'},
              'videos': [
                {
                  'id': 7,
                  'title': 'Accounting introduction',
                  'average_rating': 4.5,
                  'review_count': 2,
                },
                {'id': 8, 'title': 'Worked accounting example'},
              ],
              'notes': [],
            },
          });
        }
        if (request.url.path.endsWith('/objectives/4/resources')) {
          return _json({
            'data': {
              'objective': {'name': 'Prepare a statement'},
              'videos': [],
              'notes': [],
            },
          });
        }
        if (request.url.path.endsWith('/videos/8')) {
          return _json({
            'data': {
              'title': 'Worked accounting example',
              'access': {'allowed': false, 'reason': 'playback_setup_pending'},
            },
          });
        }
        if (request.url.path.endsWith('/courses/41')) {
          return _json({
            'data': {
              ..._course(),
              'sections': [
                {
                  'id': 1,
                  'name': 'Actual section',
                  'chapters': [
                    {
                      'id': 2,
                      'name': 'Actual chapter',
                      'objectives': [
                        {
                          'id': 3,
                          'name': 'Explain accounting',
                          'status': 'practice',
                        },
                        {
                          'id': 4,
                          'name': 'Prepare a statement',
                          'status': 'not_started',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          });
        }
        return _json(_page());
      });
      expect(find.text('Real Accounting'), findsOneWidget);
      expect(find.text('60% objectives started'), findsOneWidget);
      expect(find.textContaining('20% mastered'), findsOneWidget);
      await tester.tap(find.text('Open course'));
      await tester.pumpAndSettle();
      expect(find.text('Actual section'), findsOneWidget);
      expect(previewRequests, 1);
      await tester.ensureVisible(find.text('Actual section'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actual section'));
      await tester.pumpAndSettle();
      expect(find.text('Explain accounting'), findsNothing);
      final jump = find.text('Jump to section or chapter…');
      await tester.ensureVisible(jump);
      await tester.pumpAndSettle();
      await tester.tap(jump);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Explain accounting');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Explain accounting'));
      await tester.pumpAndSettle();
      expect(find.text('Explain accounting'), findsOneWidget);
      expect(_statusMarker('Practice'), findsOneWidget);
      expect(_statusMarker('Not started'), findsOneWidget);
      expect(previewRequests, 2);
      expect(find.text('4.5 (2)'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next videos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next videos'));
      await tester.pumpAndSettle();
      final video = find.text('Worked accounting example');
      await tester.ensureVisible(video);
      await tester.pumpAndSettle();
      expect(find.text('No ratings yet'), findsOneWidget);
      await tester.tap(video);
      await tester.pumpAndSettle();
      expect(
        find.text('Playback is not available in this build yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('No member courses shows an honest empty state', (tester) async {
    await _open(tester, (_) async => _json(_page(courses: [])));
    expect(find.text('No learning progress yet'), findsOneWidget);
    expect(find.text('Real Accounting'), findsNothing);
    await tester.tap(find.text('Browse courses'));
    await tester.pumpAndSettle();
    expect(find.text('ALL COURSES'), findsOneWidget);
  });

  testWidgets(
    'Failed request can retry and load another page without losing the first',
    (tester) async {
      var calls = 0;
      await _open(tester, (request) async {
        calls++;
        if (calls == 1) return _json({}, 503);
        final query = request.url.queryParameters;
        if (query['search'] == 'economics') {
          expect(query['page'], '1');
          return _json(
            _page(courses: [_course(id: 42, name: 'Real Economics')]),
          );
        }
        if (query['page'] == '2') {
          return _json(
            _page(
              courses: [_course(id: 42, name: 'Real Economics')],
              page: 2,
              last: 2,
            ),
          );
        }
        return _json(_page(last: 2));
      });
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Load more courses'));
      await tester.tap(find.text('Load more courses'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Real Economics'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Real Economics'), findsOneWidget);
      expect(find.text('Load more courses'), findsNothing);
      expect(calls, 3);

      final search = find.widgetWithText(TextField, 'Search my courses…');
      await tester.ensureVisible(search);
      await tester.enterText(search, 'economics');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Real Economics'), findsOneWidget);
      expect(find.text('Real Accounting'), findsNothing);
      expect(calls, 4);
    },
  );

  testWidgets('Expired token clears the member learning screen', (
    tester,
  ) async {
    final session = await _open(tester, (_) async => _json({}, 401));
    expect(session.member, isNull);
    expect(find.text('Login to your account'), findsOneWidget);
    expect(find.text('Real Accounting'), findsNothing);
  });

  test('Late course response cannot return data after sign-out', () async {
    final pending = Completer<http.Response>();
    final api = MemberApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        final public = defaultPublicResponse(request);
        if (public != null) return public;
        if (request.url.path.endsWith('/login')) {
          return _json({'token': 'token', 'user': _user});
        }
        if (request.url.path.endsWith('/logout')) return _json({});
        return pending.future;
      }),
    );
    final session = MemberSession(api: api, store: _TokenStore());
    await session.login('student@example.test', 'password');
    final request = session.courses();
    final expectation = expectLater(request, throwsA(isA<ApiException>()));
    await session.logout();
    pending.complete(_json(_page()));
    await expectation;
    expect(session.member, isNull);
    session.dispose();
    api.close();
  });
}
