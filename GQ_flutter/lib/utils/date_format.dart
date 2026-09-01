const _kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as e.g. "24 Dec" — used for wish unlock dates and chat
/// "hidden since" subtitles. No `intl` dependency; the app only ever needs
/// this one short form.
String formatShortDate(DateTime date) {
  return '${date.day} ${_kShortMonths[date.month - 1]}';
}
