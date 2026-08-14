// Copyright (C) 2026 mathiiiiiis
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.

// ==== code tables ====
// values mirror android.app.ApplicationExitInfo
const _reasons = <int, String>{
  0: 'unknown',
  1: 'exit self',
  2: 'signaled',
  3: 'low memory',
  4: 'crash',
  5: 'native crash',
  6: 'anr',
  7: 'initialization failure',
  8: 'permission change',
  9: 'excessive resource usage',
  10: 'user requested',
  11: 'user stopped',
  12: 'dependency died',
  13: 'other kill by system',
  14: 'freezer',
  15: 'package state change',
  16: 'package updated',
};

// values mirror ActivityManager.RunningAppProcessInfo
const _importances = <int, String>{
  100: 'foreground',
  125: 'foreground service',
  200: 'visible',
  230: 'perceptible',
  300: 'service',
  325: 'top sleeping',
  350: 'cant save state',
  400: 'cached',
  1000: 'gone',
};

const _signals = <int, String>{
  4: 'SIGILL',
  6: 'SIGABRT',
  7: 'SIGBUS',
  8: 'SIGFPE',
  9: 'SIGKILL',
  11: 'SIGSEGV',
};

/// One recorded process death
///
/// Android only, api needs skd 30
/// > reason: why system ended process
/// > status: signal number when reason is signaled, else exit code
/// > importance: process importance at moment of death
/// > pss, rss: memory at death (kilobytes)
/// > trace: anr or native trace when system kept one
class ExitRecord {
  const ExitRecord({
    required this.timestamp,
    required this.pid,
    required this.processName,
    required this.reason,
    required this.status,
    required this.importance,
    required this.pss,
    required this.rss,
    this.description,
    this.trace,
  });

  final DateTime timestamp;
  final int pid;
  final String? processName;
  final int reason;
  final int status;
  final int importance;
  final int pss;
  final int rss;
  final String? description;
  final String? trace;

  String get reasonName => _reasons[reason] ?? 'reason $reason';
  String get importanceName => _importances[importance] ?? '$importance';
  String? get signalName => reason == 2 ? _signals[status] : null;

  factory ExitRecord.fromMap(Map<Object?, Object?> map) {
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;
    return ExitRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(intOf('timestamp')),
      pid: intOf('pid'),
      processName: map['processName'] as String?,
      reason: intOf('reason'),
      status: intOf('status'),
      importance: intOf('importance'),
      pss: intOf('pss'),
      rss: intOf('rss'),
      description: map['description'] as String?,
      trace: map['trace'] as String?,
    );
  }
}
