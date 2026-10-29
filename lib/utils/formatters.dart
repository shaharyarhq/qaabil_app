/// Small text helpers used by the UI.
library;

/// "1 section", "11 sections".
String pluralize(int count, String word) {
  return '$count ${count == 1 ? word : '${word}s'}';
}

/// A friendly "4 days ago" / "1 month ago" style date.
String timeAgo(DateTime date, {DateTime? now}) {
  final days = (now ?? DateTime.now()).difference(date).inDays;

  if (days < 1) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';

  final months = days ~/ 30;
  if (months < 12) return '${pluralize(months, 'month')} ago';

  return '${pluralize(days ~/ 365, 'year')} ago';
}
