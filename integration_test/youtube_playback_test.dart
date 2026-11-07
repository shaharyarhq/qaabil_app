import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qaabil_mobile/widgets/youtube_video.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const videoId = String.fromEnvironment(
    'TEST_YOUTUBE_ID',
    defaultValue: 'URJuE4nlc7U',
  );

  Future<void> waitForState(
    WidgetTester tester,
    YoutubePlayerController controller,
    Set<PlayerState> states,
  ) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (states.contains(controller.value.playerState) ||
          controller.value.hasError) {
        break;
      }
    }
    expect(controller.value.error, YoutubeError.none);
    expect(states, contains(controller.value.playerState));
  }

  Widget lesson(String id) => MaterialApp(
    home: Scaffold(body: YoutubeVideo(videoId: id)),
  );
  YoutubePlayerController player(WidgetTester tester) =>
      tester.widget<YoutubePlayer>(find.byType(YoutubePlayer)).controller;

  testWidgets(
    'Published lesson plays, pauses and recovers after a source error',
    (tester) async {
      final report = <String, Object>{};
      binding.reportData = report;
      try {
        await tester.pumpWidget(lesson(videoId));
        var controller = player(tester);
        // Readiness is not enough: cueVideoById must finish before playVideo.
        await waitForState(tester, controller, {PlayerState.cued});
        await controller.playVideo();
        await waitForState(tester, controller, {PlayerState.playing});
        final before = await controller.currentTime;
        await tester.pump(const Duration(seconds: 3));
        final after = await controller.currentTime;
        expect(
          after,
          greaterThan(before),
          reason: 'The actual video timeline must advance.',
        );
        report['playback'] = 'playing; video time advanced';
        await controller.pauseVideo();
        await waitForState(tester, controller, {PlayerState.paused});
        report['pause'] = 'passed';

        // Invalid input belongs only to this test, never backend lesson data.
        await tester.pumpWidget(lesson('invalid'));
        for (
          var i = 0;
          i < 80 && find.text('Retry video').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(find.text('Retry video'), findsOneWidget);
        await tester.ensureVisible(find.text('Retry video'));
        await tester.tap(find.text('Retry video'));
        await tester.pump(const Duration(milliseconds: 500));
        // Switching back to the approved source must replace the failed player.
        await tester.pumpWidget(lesson(videoId));
        controller = player(tester);
        await waitForState(tester, controller, {PlayerState.cued});
        expect(find.text('Retry video'), findsNothing);
        await controller.playVideo();
        await waitForState(tester, controller, {PlayerState.playing});
        report['error_retry_and_source_change'] = 'passed';
        await controller.pauseVideo();
      } finally {
        debugPrint('PLAYBACK_REPORT: $report');
        await tester.pumpWidget(const SizedBox());
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
