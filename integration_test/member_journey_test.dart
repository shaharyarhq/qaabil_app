import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:qaabil_mobile/auth/member_session.dart';
import 'package:qaabil_mobile/main.dart';
import 'package:qaabil_mobile/models/catalogue_course.dart';
import 'package:qaabil_mobile/screens/lesson_video_screen.dart';
import 'package:qaabil_mobile/services/member_api.dart';
import 'package:qaabil_mobile/widgets/course_card.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Run only against a prepared local test member, never a real member account.
/// Supply its credentials via an untracked --dart-define-from-file JSON file.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('TEST_EMAIL');
  const password = String.fromEnvironment('TEST_PASSWORD');
  const courseName = String.fromEnvironment('TEST_COURSE_NAME');
  const chapterName = String.fromEnvironment('TEST_CHAPTER_NAME');
  const objectiveName = String.fromEnvironment('TEST_OBJECTIVE_NAME');
  const objectiveId = int.fromEnvironment('TEST_OBJECTIVE_ID');
  const videoId = int.fromEnvironment('TEST_VIDEO_ID');

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (finder.evaluate().isEmpty) {
      debugPrint(
        'Visible labels: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList()}',
      );
    }
    expect(finder, findsWidgets);
    FocusManager.instance.primaryFocus?.unfocus();
    // Let keyboard dismissal and route transitions finish before the next tap.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> search(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    debugPrint(
      'SMOKE_SEARCH: ${tester.widget<TextField>(find.byType(TextField)).controller?.text}',
    );
  }

  Finder courseCard(String name) =>
      find.descendant(of: find.byType(CourseCard), matching: find.text(name));

  testWidgets(
    'Real local API: guest browsing, member login, resources and logout',
    (tester) async {
      expect(
        email.startsWith('device-smoke-') && email.endsWith('@example.invalid'),
        isTrue,
        reason: 'Use a disposable local test member.',
      );
      final api = MemberApi(client: _DiagnosticClient());
      // Isolate test credentials from the app's normal saved member session.
      final store = SecureTokenStore('${api.baseUrl}/device-smoke-test');
      final session = MemberSession(api: api, store: store);
      final checks = <String, Object>{};
      binding.reportData = checks;
      await store.clear();
      try {
        CataloguePage? catalogue;
        // flutter's device launch can clear adb reverse. Give the host time to restore it.
        for (var i = 0; i < 30 && catalogue == null; i++) {
          try {
            catalogue = await api.catalogue();
          } on ApiException {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
        expect(
          catalogue,
          isNotNull,
          reason: 'Restore the local API adb reverse tunnel.',
        );
        await tester.pumpWidget(QaabilApp(session: session));
        await tester.pump();
        await search(tester, courseName);
        await waitFor(tester, courseCard(courseName));
        expect(catalogue!.courses.any((c) => c.name == courseName), isTrue);
        checks['public_catalogue'] = 'passed';

        checks['initial_course_search'] = 'passed';

        await tester.ensureVisible(courseCard(courseName));
        await tester.tap(courseCard(courseName));
        await waitFor(tester, find.text(chapterName));
        await tester.ensureVisible(find.text(chapterName));
        await tester.tap(find.text(chapterName));
        await waitFor(tester, find.text(objectiveName));
        expect(find.text('Practice'), findsNothing);
        final objective = find
            .ancestor(
              of: find.text(objectiveName),
              matching: find.byType(Column),
            )
            .first;
        final guestResources = find.descendant(
          of: objective,
          matching: find.widgetWithText(TextButton, 'Login for videos & notes'),
        );
        await tester.ensureVisible(guestResources);
        await tester.tap(guestResources);
        await waitFor(tester, find.byType(TextFormField));
        checks['guest_content_and_login_gate'] = 'passed';

        await tester.enterText(find.byType(TextFormField).at(0), email);
        await tester.enterText(find.byType(TextFormField).at(1), password);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
        await tester.tap(find.widgetWithText(FilledButton, 'Login'));
        await waitFor(tester, find.text('Practice'));
        expect(session.member, isNotNull);
        expect(await store.read(), isNotNull);
        checks['login_and_private_progress'] = 'passed';

        final memberResources = find.descendant(
          of: objective,
          matching: find.widgetWithText(TextButton, 'Videos & notes'),
        );
        await tester.ensureVisible(memberResources);
        await tester.tap(memberResources);
        await waitFor(tester, find.text('Videos'));
        await tester.scrollUntilVisible(find.text('Objective notes'), 300,
            scrollable: find.byType(Scrollable).last);
        await tester.pump(const Duration(milliseconds: 500));
        final resources = await session.resources(objectiveId);
        expect(resources.videos.any((v) => v.id == videoId), isTrue);
        checks['approved_resource_list'] = 'passed';
        if (resources.notes.isEmpty) {
          expect(find.text('No notes have been added yet.'), findsOneWidget);
          checks['notes'] = 'Empty state passed; no local note available for device download.';
        } else {
          final bytes = await api.note(
            (await store.read())!,
            objectiveId,
            resources.notes.first.id,
          );
          expect(bytes.length, resources.notes.first.size);
          checks['notes'] =
              'Authenticated download passed; external viewer not checked.';
        }

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('My Learning'));
        await waitFor(tester, find.text('Open course'));
        expect(find.text(courseName), findsOneWidget);
        checks['my_learning'] = 'passed';

        final restored = MemberSession(api: api, store: store);
        await restored.restore();
        expect(restored.member?.id, session.member?.id);
        restored.dispose();
        checks['secure_session_restore'] = 'passed';

        // Check the actual platform WebView and YouTube iframe, not a widget mock.
        final context = tester.element(find.text('My Learning').first);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const LessonVideoScreen(videoId: videoId),
          ),
        );
        await waitFor(tester, find.byType(YoutubePlayer));
        final controller = tester
            .widget<YoutubePlayer>(find.byType(YoutubePlayer))
            .controller;
        try {
          // The iframe can be ready before its initial cue request has completed.
          for (var i = 0; i < 80; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            if (controller.value.playerState == PlayerState.cued ||
                controller.value.hasError) {
              break;
            }
          }
          expect(controller.value.error, YoutubeError.none);
          expect(controller.value.playerState, PlayerState.cued);
          await controller.playVideo().timeout(const Duration(seconds: 20));
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            if (controller.value.hasError ||
                controller.value.playerState == PlayerState.playing) {
              break;
            }
          }
          checks['youtube_playback'] =
              controller.value.playerState == PlayerState.playing
              ? 'passed: player reports playing'
              : 'Not playing: ${controller.value.playerState.name}, error ${controller.value.error.name}';
          if (controller.value.playerState == PlayerState.playing) {
            await controller.pauseVideo();
          }
        } on TimeoutException {
          checks['youtube_playback'] =
              'Iframe did not become ready within 20 seconds.';
        }
        if (const bool.fromEnvironment('TEST_VIDEO_PAGE')) {
          Future<void> tab(String name) async {
            final chip = find.widgetWithText(ChoiceChip, name);
            await waitFor(tester, chip);
            await tester.ensureVisible(chip);
            await tester.tap(chip);
            await tester.pump(const Duration(milliseconds: 500));
          }

          await tab('Overview');
          await waitFor(
            tester,
            find.text(
              'Disposable video-page metadata for device verification.',
            ),
          );
          final details = await session.videoDetails(videoId);
          expect(details.related, isNotEmpty);
          expect(details.materials, isNotEmpty);
          checks['video_overview_and_related'] = 'passed';
          await tab('Materials');
          await waitFor(tester, find.text('lesson.txt'));
          final bytes = await api.videoMaterial(
            (await store.read())!,
            videoId,
            details.materials.first,
          );
          expect(utf8.decode(bytes), 'Disposable mobile learning material.');
          checks['video_material_download'] = 'passed';
          await tab('Reviews');
          await waitFor(tester, find.text('Submit review'));
          await tester.ensureVisible(find.byTooltip('4 stars'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.byTooltip('4 stars'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.ensureVisible(find.byType(TextField));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.enterText(
            find.byType(TextField),
            'Temporary device review for app verification.',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.ensureVisible(find.text('Submit review'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.text('Submit review'));
          await waitFor(
            tester,
            find.text('You have already reviewed this video.'),
          );
          expect(
            find.text('Temporary device review for app verification.'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Delete my review'));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.text('Delete my review'));
          await waitFor(tester, find.text('Delete your review?'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(
            find.text('Temporary device review for app verification.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Delete my review'));
          await waitFor(tester, find.text('Delete your review?'));
          await tester.tap(find.widgetWithText(FilledButton, 'Delete review'));
          await waitFor(tester, find.text('Submit review'));
          checks['video_review_submit_cancel_delete'] = 'passed';
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profile'));
        await waitFor(tester, find.text('Sign out'));
        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await waitFor(tester, find.text('Login to your account'));
        expect(session.member, isNull);
        expect(await store.read(), isNull);
        checks['logout'] = 'passed';
        expect(checks['youtube_playback'], 'passed: player reports playing');
        expect(tester.takeException(), isNull);
      } finally {
        debugPrint('DEVICE_SMOKE_RESULTS: $checks');
        if (session.member != null) await session.logout();
        await store.clear();
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        api.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _DiagnosticClient extends http.BaseClient {
  final _client = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Never log headers, credentials, tokens or request bodies.
    debugPrint(
      'SMOKE_REQUEST: ${request.method} ${request.url.path}?${request.url.query}',
    );
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
