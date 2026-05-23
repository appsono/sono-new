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
