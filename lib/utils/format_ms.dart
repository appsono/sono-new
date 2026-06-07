import 'package:sono/l10n/localizations.dart';

/// Compact duration "1h 23m" or "42m"
/// USed for collection total (album, playlist, artist subtitles)
String fmtMsCompact(int ms, AppLocalizations l) {
  final totalMinutes = ms ~/ 60000;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) return l.commonDurationLong(hours, minutes);
  return l.commonDurationShort(minutes);
}

// ==== format ====
String fmt(Duration d) {
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

String fmtMs(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}
