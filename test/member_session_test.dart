import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/main.dart';
import 'package:qaabil_mobile/services/member_api.dart';

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
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(TextButton, 'Login'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('member@example.test'), findsOneWidget);
    expect(find.text('Test School'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.first).controller!.text,
      'Example Member',
    );
    await tester.enterText(fields.first, ' Updated Member ');
    await tester.enterText(fields.last, '');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('The member service is unavailable. Please try again later.'),
      findsOneWidget,
    );
    expect(session.member!.school, 'Test School');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Member'), findsOneWidget);
    expect(find.text('Not added'), findsOneWidget);
    expect(find.text('Profile saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
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
      await tester.ensureVisible(find.text('My Video Submissions'));
      await tester.tap(find.text('My Video Submissions'));
      await tester.pumpAndSettle();
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Math › Solve a problem'), findsOneWidget);
      await tester.ensureVisible(find.text('Load more submissions'));
      await tester.tap(find.text('Load more submissions'));
      await tester.pumpAndSettle();
      expect(find.text('Fraction practice'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(pages, ['1', '2']);
      expect(find.text('Load more submissions'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    },
  );
}
