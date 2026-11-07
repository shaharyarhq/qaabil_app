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

  testWidgets('Member can log in, view real profile fields and sign out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = MemberApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({'token': 'test-token', 'user': user}),
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
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Login to your account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
}
