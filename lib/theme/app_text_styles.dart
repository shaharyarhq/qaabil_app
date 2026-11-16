import 'package:flutter/material.dart';

/// Bold, rounded typography for the playful Qaabil interface.
class AppTextStyles {
  AppTextStyles._();

  static const String sans = 'PlusJakartaSans';
  static const String serif = 'InstrumentSerif';

  /// Big page headings, e.g. "Welcome back".
  static const TextStyle heading = TextStyle(
    fontFamily: sans,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.5,
  );

  /// Bold highlighted words inside a heading.
  static const TextStyle headingAccent = TextStyle(
    fontFamily: sans,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w800,
    fontSize: 30,
    letterSpacing: 0,
  );

  /// Small uppercase label above a heading, e.g. "MY COURSES".
  static const TextStyle eyebrow = TextStyle(
    fontFamily: sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );

  /// Big course card titles.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: sans,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// Small uppercase text inside pills, e.g. "11 SECTIONS".
  static const TextStyle pill = TextStyle(
    fontFamily: sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  /// Small grey text, e.g. "📚 55 chapters".
  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
  );

  /// Compact course metadata, e.g. "4 days ago".
  static const TextStyle serifCaption = TextStyle(
    fontFamily: sans,
    fontStyle: FontStyle.normal,
    fontSize: 14,
  );

  /// Card titles.
  static const TextStyle title = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  /// Normal paragraph text.
  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Labels above text fields.
  static const TextStyle label = TextStyle(
    fontFamily: sans,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
  );

  /// Text inside buttons.
  static const TextStyle button = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );
}
