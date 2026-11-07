import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/main.dart';
import 'package:qaabil_mobile/services/member_api.dart';
import 'package:qaabil_mobile/widgets/filter_pill.dart';

import 'support/public_catalogue.dart';

class _Store implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

Future<void> openCourses(
  WidgetTester tester, {
  Future<http.Response> Function(http.Request)? respond,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = MemberApi(
    baseUrl: 'https://example.test/api/v1',
    client: MockClient((request) async {
      expect(request.headers['Authorization'], isNull);
      return respond == null ? publicJson(publicPage()) : respond(request);
    }),
  );
  final session = MemberSession(api: api, store: _Store());
  await tester.pumpWidget(QaabilApp(session: session));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
}

Future<void> search(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Guests see backend courses without credentials or mock courses',
    (tester) async {
      await openCourses(tester);
      expect(find.text('Backend Accounting'), findsOneWidget);
      expect(find.text('Biology (0610)'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Backend Accounting'), findsOneWidget);
    },
  );

  testWidgets('Search, dynamic qualification and sort are sent to server', (
    tester,
  ) async {
    final requests = <Uri>[];
    await openCourses(
      tester,
      respond: (r) async {
        requests.add(r.url);
        return publicJson(publicPage());
      },
    );
    await search(tester, 'Accounting & more');
    expect(requests.last.queryParameters['search'], 'Accounting & more');
    await tester.tap(find.widgetWithText(FilterPill, 'Backend Qualification'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['qualification'], '9');
    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first').last);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['sort'], 'oldest');
  });

  testWidgets('Empty search can be cleared and tabs preserve search', (
    tester,
  ) async {
    await openCourses(
      tester,
      respond: (r) async => publicJson(
        publicPage(
          courses: r.url.queryParameters['search'] == 'zzz' ? [] : null,
        ),
      ),
    );
    await search(tester, 'zzz');
    expect(find.text('No courses found'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'zzz',
    );
    await tester.tap(find.text('Clear search & filters'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Accounting'), findsOneWidget);
  });

  testWidgets(
    'Service error has retry without sample fallback; pagination appends',
    (tester) async {
      var fail = true;
      await openCourses(
        tester,
        respond: (r) async {
          if (fail) return publicJson({}, 503);
          final second = r.url.queryParameters['page'] == '2';
          return publicJson(
            publicPage(
              courses: second
                  ? [publicCourse(id: 19, name: 'Another Backend Course')]
                  : null,
              page: second ? 2 : 1,
              last: 2,
            ),
          );
        },
      );
      expect(find.text('Backend Accounting'), findsNothing);
      expect(find.text('Biology (0610)'), findsNothing);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Load more courses'));
      await tester.tap(find.text('Load more courses'));
      await tester.pumpAndSettle();
      expect(find.text('Backend Accounting'), findsOneWidget);
      expect(find.text('Another Backend Course'), findsOneWidget);
      expect(find.text('Load more courses'), findsNothing);
    },
  );

  testWidgets('Guest opens real course content and login for resources', (
    tester,
  ) async {
    await openCourses(
      tester,
      respond: (r) async {
        if (r.url.path.endsWith('/18')) {
          return publicJson({
            'data': {
              'id': 18,
              'name': 'Backend Accounting',
              'sections': [
                {
                  'id': 2,
                  'name': 'Backend Section',
                  'chapters': [
                    {
                      'id': 3,
                      'name': 'Backend Chapter',
                      'objectives': [
                        {'id': 4, 'name': 'Backend Objective'},
                      ],
                    },
                  ],
                },
              ],
            },
          });
        }
        return publicJson(publicPage());
      },
    );
    await tester.tap(find.text('Backend Accounting'));
    await tester.pumpAndSettle();
    expect(find.text('Course content'), findsOneWidget);
    expect(find.text('Backend Section'), findsOneWidget);
    await tester.tap(find.text('Backend Chapter'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Objective'), findsOneWidget);
    expect(find.text('Not started'), findsNothing);
    expect(find.text('Take Quiz'), findsNothing);
    await tester.tap(find.text('Login for videos & notes'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Backend Objective'), findsOneWidget);
  });

  testWidgets('Late search response cannot replace newer results', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    await openCourses(
      tester,
      respond: (r) async {
        final query = r.url.queryParameters['search'];
        if (query == 'old') return old.future;
        return publicJson(
          publicPage(
            courses: [
              publicCourse(
                name: query == 'new' ? 'New Result' : 'Backend Accounting',
              ),
            ],
          ),
        );
      },
    );
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 350));
    await search(tester, 'new');
    old.complete(
      publicJson(publicPage(courses: [publicCourse(name: 'Old Result')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Result'), findsOneWidget);
    expect(find.text('Old Result'), findsNothing);
  });
}
