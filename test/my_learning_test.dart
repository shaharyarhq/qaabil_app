import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
      expect(request.headers['Authorization'], 'Bearer token');
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

void main() {
  testWidgets(
    'Real course progress opens its own course content with saved statuses',
    (tester) async {
      await _open(tester, (request) async {
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
      await tester.ensureVisible(find.text('Actual chapter'));
      await tester.tap(find.text('Actual chapter'));
      await tester.pumpAndSettle();
      expect(find.text('Explain accounting'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
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
        if (request.url.queryParameters['page'] == '2') {
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
