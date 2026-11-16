import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/main.dart';
import 'package:qaabil_mobile/screens/profile_screen.dart';
import 'package:qaabil_mobile/services/member_api.dart';

import 'support/public_catalogue.dart';

class MemoryTokenStore implements TokenStore {
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

const user = {
  'id': 7,
  'name': 'Test Member',
  'email': 'member@example.test',
  'full_name': 'Example Member',
  'school': 'Test School',
};

Future<void> scrollProfile(WidgetTester tester, String label) =>
    tester.scrollUntilVisible(
      find.text(label),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  test(
    'Login sends credentials once and saves token; restore uses bearer token',
    () async {
      final store = MemoryTokenStore();
      final api = MemberApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            expect(request.bodyFields['email'], user['email']);
            expect(request.bodyFields['password'], 'test-password');
            return http.Response(
              jsonEncode({'token': 'secret-test-token', 'user': user}),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer secret-test-token');
          return http.Response(jsonEncode({'user': user}), 200);
        }),
      );
      final session = MemberSession(api: api, store: store);
      expect(
        await session.login('member@example.test', 'test-password'),
        isTrue,
      );
      expect(store.token, 'secret-test-token');
      final restored = MemberSession(api: api, store: store);
      await restored.restore();
      expect(restored.member!.id, 7);
      session.dispose();
      restored.dispose();
      api.close();
    },
  );

  test(
    'Expired stored token is removed; server errors never expose debug details',
    () async {
      final store = MemoryTokenStore()..token = 'expired';
      final api = MemberApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'internal-secret-details'}),
            401,
          ),
        ),
      );
      final session = MemberSession(api: api, store: store);
      await session.restore();
      expect(store.token, isNull);
      expect(session.member, isNull);
      expect(session.error, isNot(contains('internal-secret')));
      session.dispose();
      api.close();
    },
  );

  test('Failed logout retains session so revocation can be retried', () async {
    var fail = true;
    final store = MemoryTokenStore();
    final api = MemberApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({'token': 'test-token', 'user': user}),
            200,
          );
        }
        return http.Response('{}', fail ? 503 : 200);
      }),
    );
    final session = MemberSession(api: api, store: store);
    await session.login('member@example.test', 'test-password');
    expect(await session.logout(), isFalse);
    expect(session.member, isNotNull);
    fail = false;
    expect(await session.logout(), isTrue);
    expect(session.member, isNull);
    expect(store.token, isNull);
    session.dispose();
    api.close();
  });

  testWidgets('Member can log in, edit profile fields and sign out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var saves = 0;
    final api = MemberApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({'token': 'test-token', 'user': user}),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/me')) {
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.bodyFields, {
            'full_name': 'Updated Member',
            'school': '',
          });
          if (++saves == 1) return http.Response('{}', 503);
          return http.Response(
            jsonEncode({
              'user': {...user, 'full_name': 'Updated Member', 'school': null},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final session = MemberSession(api: api, store: MemoryTokenStore());
    await tester.pumpWidget(QaabilApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Login'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(TextButton, 'Login'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('member@example.test'), findsOneWidget);
    expect(find.text('Test School'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.ensureVisible(find.text('Update'));
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      'Example Member',
    );
    await tester.enterText(fields.at(2), ' Updated Member ');
    await tester.enterText(fields.last, '');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(
      find.text('The member service is unavailable. Please try again later.'),
      findsOneWidget,
    );
    expect(session.member!.school, 'Test School');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Member'), findsOneWidget);
    expect(tester.widget<TextFormField>(fields.last).controller!.text, isEmpty);
    expect(find.text('Profile updated successfully!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await scrollProfile(tester, 'Sign out');
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Login to your account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
  testWidgets(
    'Forgot password requests a code and changes the password inside the app',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final code = List.filled(64, 'a').join();
      final calls = <String>[];
      final api = MemberApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          if (request.method != 'POST') return http.Response('{}', 200);
          calls.add(request.url.path);
          expect(request.bodyFields['email'], 'member@example.test');
          if (request.url.path.endsWith('/reset')) {
            expect(request.bodyFields['token'], code);
            expect(
              request.bodyFields['password_confirmation'],
              'updated-password',
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final session = MemberSession(api: api, store: MemoryTokenStore());
      await tester.pumpWidget(QaabilApp(session: session));
      await tester.pumpAndSettle();

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await tap('Login');
      await tap('Forgot password?');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'member@example.test');
      await tap('Send reset code');
      await tester.enterText(fields.at(1), code);
      await tester.enterText(fields.at(2), 'updated-password');
      await tester.enterText(fields.at(3), 'updated-password');
      await tap('Change password');
      expect(calls, [
        '/api/v1/member/password/request',
        '/api/v1/member/password/reset',
      ]);
      expect(
        find.text('Password changed. Sign in with your new password.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    },
  );
  testWidgets(
    'Profile opens the member submissions list and loads the next page',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pages = <String?>[];
      final api = MemberApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/me')) {
            return http.Response(jsonEncode({'user': user}), 200);
          }
          if (request.url.path.endsWith('/submissions')) {
            expect(request.headers['Authorization'], 'Bearer test-token');
            final page = request.url.queryParameters['page'];
            pages.add(page);
            final first = page == '1';
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': first ? 7 : 6,
                    'title': first ? 'Fraction practice' : 'Basic equations',
                    'status': first ? 'pending' : 'rejected',
                    'course': 'Math',
                    'objective': 'Solve a problem',
                    'section': 'Number',
                    'chapter': 'Fractions',
                    'approved_by': first ? null : 'Reviewer',
                    'submitted_at': '2026-11-13T12:00:00Z',
                  },
                ],
                'meta': {'current_page': first ? 1 : 2, 'last_page': 2},
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final session = MemberSession(
        api: api,
        store: MemoryTokenStore()..token = 'test-token',
      );
      await tester.pumpWidget(QaabilApp(session: session));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await scrollProfile(tester, 'My Video Submissions');
      await tester.tap(find.text('My Video Submissions'));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
      expect(
        find.text('Objective  Solve a problem', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Submitted '), findsOneWidget);
      await tester.ensureVisible(find.text('Load more submissions'));
      await tester.tap(find.text('Load more submissions'));
      await tester.pumpAndSettle();
      expect(find.text('Fraction practice'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      tester.view.physicalSize = const Size(1180, 844);
      await tester.pumpAndSettle();
      expect(find.text('Approved By'), findsOneWidget);
      expect(find.text('Reviewer'), findsOneWidget);
      expect(pages, ['1', '2']);
      expect(find.text('Load more submissions'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    },
  );
  testWidgets(
    'Member submits and edits a YouTube video from their submissions',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var submitted = false;
      var edited = false;
      final api = MemberApi(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/me')) return publicJson({'user': user});
          if (path.endsWith('/courses')) return publicJson(publicPage());
          if (path.endsWith('/courses/18')) {
            return publicJson({
              'data': {
                ...publicCourse(),
                'sections': [
                  {
                    'id': 1,
                    'name': 'Accounts',
                    'chapters': [
                      {
                        'id': 2,
                        'name': 'Introduction',
                        'objectives': [
                          {'id': 3, 'name': 'Explain assets'},
                        ],
                      },
                    ],
                  },
                ],
              },
            });
          }
          if (path.endsWith('/submissions/options')) {
            return publicJson({
              'languages': {'en': 'English'},
              'focuses': {'lesson_focused': 'Lesson Focused'},
            });
          }
          if (path.endsWith('/submissions/9')) {
            expect(request.headers['Authorization'], 'Bearer test-token');
            if (request.method == 'POST') {
              expect(request.bodyFields['title'], 'Updated assets walkthrough');
              expect(request.bodyFields['objective_id'], '3');
              expect(request.bodyFields['description'], 'An explanation');
              edited = true;
              return publicJson({'id': 9, 'status': 'pending'});
            }
            return publicJson({
              'id': 9,
              'title': 'Assets walkthrough',
              'status': 'approved',
              'video_url': 'https://youtu.be/eNEgvVJI_zw',
              'course_id': 18,
              'course': 'Backend Accounting',
              'objective_id': 3,
              'objective': 'Explain assets',
              'language': 'en',
              'focus_of_the_video': 'lesson_focused',
              'description': 'An explanation',
            });
          }
          if (path.endsWith('/submissions') && request.method == 'POST') {
            expect(request.headers['Authorization'], 'Bearer test-token');
            expect(request.bodyFields, {
              'title': 'Assets walkthrough',
              'video_url': 'https://youtu.be/eNEgvVJI_zw',
              'objective_id': '3',
              'language': 'en',
              'focus_of_the_video': 'lesson_focused',
              'description': '',
            });
            submitted = true;
            return publicJson({
              'id': 9,
              'status': 'pending',
              'created': true,
            }, 201);
          }
          return publicJson({
            'data': [
              if (submitted)
                {
                  'id': 9,
                  'title': edited
                      ? 'Updated assets walkthrough'
                      : 'Assets walkthrough',
                  'status': 'pending',
                },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        }),
      );
      final session = MemberSession(
        api: api,
        store: MemoryTokenStore()..token = 'test-token',
      );
      await tester.pumpWidget(QaabilApp(session: session));
      await tester.pumpAndSettle();

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Profile'));
      await scrollProfile(tester, 'My Video Submissions');
      await tap(find.text('My Video Submissions'));
      await tap(find.text('Submit video'));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Assets walkthrough',
      );
      await tap(find.byTooltip('Course'));
      await tap(find.text('Backend Accounting').last);
      await tap(find.byTooltip('Objective'));
      final optionSearch = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(optionSearch, 'missing label');
      await tester.pumpAndSettle();
      expect(find.text('No matching options'), findsOneWidget);
      await tester.enterText(optionSearch, 'ASSETS explain');
      await tester.pumpAndSettle();
      await tap(find.textContaining('Explain assets').last);
      await tap(find.byTooltip('Focus'));
      await tap(find.text('Lesson Focused').last);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'https://youtu.be/eNEgvVJI_zw',
      );
      await tester.pumpAndSettle();
      expect(find.text('Preview video'), findsOneWidget);
      await tap(find.text('Submit for review'));

      expect(find.text('Video submitted for review.'), findsOneWidget);
      expect(find.text('Assets walkthrough'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      await tap(find.text('Edit'));
      expect(find.text('Edit video'), findsOneWidget);
      expect(find.text('An explanation'), findsOneWidget);
      expect(find.textContaining('send it back for review'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Updated assets walkthrough',
      );
      await tap(find.text('Save changes'));
      expect(edited, isTrue);
      expect(find.text('Updated assets walkthrough'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    },
  );
}
