import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaabil_mobile/main.dart';
import 'package:qaabil_mobile/widgets/filter_pill.dart';

/// Opens the app and taps Login, so each test starts on the Courses screen.
Future<void> openCourses(WidgetTester tester) async {
  // A tall test screen, so every course card fits without scrolling.
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const QaabilApp());
  await tester.tap(find.widgetWithText(FilledButton, 'Login'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Login navigates to the courses screen', (tester) async {
    await tester.pumpWidget(const QaabilApp());

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('ALL COURSES'), findsOneWidget);
  });

  testWidgets('Courses screen shows every course', (tester) async {
    await openCourses(tester);

    expect(find.text('Mathematics (0580)'), findsOneWidget);
    expect(find.text('Economics (9708)'), findsOneWidget);
  });

  testWidgets('Search filters the list', (tester) async {
    await openCourses(tester);

    await tester.enterText(find.byType(TextField), 'physics');
    await tester.pump();

    expect(find.text('Physics (0625)'), findsOneWidget);
    expect(find.text('Physics (9702)'), findsOneWidget);
    expect(find.text('Biology (0610)'), findsNothing);
  });

  testWidgets('Qualification pill filters the list', (tester) async {
    await openCourses(tester);

    await tester.tap(find.widgetWithText(FilterPill, 'Cambridge A-Level'));
    await tester.pump();

    expect(find.text('Economics (9708)'), findsOneWidget);
    expect(find.text('Mathematics (0580)'), findsNothing);
  });

  testWidgets('Shows an empty state and can clear it', (tester) async {
    await openCourses(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No courses found'), findsOneWidget);

    await tester.tap(find.text('Clear search & filters'));
    await tester.pump();
    expect(find.text('Biology (0610)'), findsOneWidget);
  });

  testWidgets('Tapping a course opens its page', (tester) async {
    await openCourses(tester);

    await tester.tap(find.text('Biology (0610)'));
    await tester.pumpAndSettle();

    // Title, section and chapters from the mock curriculum.
    expect(find.text('Biology (0610)'), findsOneWidget);
    expect(find.text('Cells and organisms'), findsOneWidget);
    expect(find.text('Chapter 3'), findsOneWidget);

    // Back returns to the list.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('ALL COURSES'), findsOneWidget);
  });

  testWidgets('Tapping a chapter shows its objectives', (tester) async {
    await openCourses(tester);
    await tester.tap(find.text('Biology (0610)'));
    await tester.pumpAndSettle();

    expect(find.text('Take Quiz'), findsNothing);

    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Compare animal and plant cells'),
      findsOneWidget,
    );
    expect(find.text('Take Quiz'), findsOneWidget);
  });

  testWidgets('Empty section shows a message', (tester) async {
    await openCourses(tester);
    await tester.tap(find.text('Economics (9708)'));
    await tester.pumpAndSettle();

    expect(
      find.text('No chapters have been added to this section yet.'),
      findsOneWidget,
    );
  });
}
