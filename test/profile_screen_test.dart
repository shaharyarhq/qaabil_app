import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/screens/profile_screen.dart';
import 'package:qaabil_mobile/services/member_api.dart';
import 'package:qaabil_mobile/theme/app_theme.dart';

class _Store implements TokenStore {
  @override
  Future<String?> read() async => 'profile-test-token';

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('Inline profile validates, retries and uses the saved values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final saves = <Map<String, dynamic>>[];
    final api = MemberApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/member/me');
        expect(request.headers['Authorization'], 'Bearer profile-test-token');
        if (request.method == 'POST') {
          saves.add(Uri.splitQueryString(request.body));
          if (saves.length == 1) {
            return http.Response(
              '{"message":"Could not save right now."}',
              503,
            );
          }
        }
        return http.Response(
          jsonEncode({
            'user': {
              'id': 1,
              'name': 'demo-member',
              'email': 'member@example.test',
              'full_name': saves.length == 2 ? 'Updated Member' : 'Demo Member',
              'school': saves.length == 2 ? null : 'Demo School',
            },
          }),
          200,
        );
      }),
    );
    final session = MemberSession(api: api, store: _Store());
    await session.restore();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    });
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: ProfileScreen(onBrowseCourses: () {}),
        ),
      ),
    );

    expect(find.text('Personal Information'), findsOneWidget);
    final fields = find.byType(EditableText);
    expect(tester.widget<EditableText>(fields.at(0)).readOnly, isTrue);
    expect(tester.widget<EditableText>(fields.at(1)).readOnly, isTrue);
    final fullName = find.ancestor(
      of: fields.at(2),
      matching: find.byType(TextFormField),
    );
    final school = find.ancestor(
      of: fields.at(3),
      matching: find.byType(TextFormField),
    );
    final update = find.widgetWithText(FilledButton, 'Update');

    await tester.enterText(fullName, 'X' * 121);
    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(find.text('Use 120 characters or fewer.'), findsOneWidget);
    expect(saves, isEmpty);

    await tester.enterText(fullName, '  Updated Member  ');
    await tester.enterText(school, '');
    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(
      find.text('The member service is unavailable. Please try again later.'),
      findsOneWidget,
    );

    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(saves.last, {'full_name': 'Updated Member', 'school': ''});
    expect(find.text('Profile updated successfully!'), findsOneWidget);
    expect(find.text('Updated Member'), findsOneWidget);
    expect(session.member!.school, isNull);
  });
}
