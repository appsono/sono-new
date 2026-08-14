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

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sono/services/build_flavor.dart';
import 'package:sono/services/diagnostic/exit_record.dart';

// ==== formatting ====
String _mbFromBytes(num? bytes) =>
    bytes == null ? 'unknown' : '${(bytes / (1024 * 1024)).round()} MB';

String _mbFromKb(num? kb) =>
    kb == null ? 'unknown' : '${(kb / 1024).round()} MB';

String _stamp(DateTime t) => t.toLocal().toString().split('.').first;

String _flag(Object? value) => switch (value) {
  true => 'yes',
  false => 'no',
  _ => 'unknown',
};

/// Collects pastable crash report
///
/// Pulls android process exit history plus battery and memory
/// state that decided wether foreground service can be reaped
class DiagnosticService {
  DiagnosticService._();
  static final instance = DiagnosticService._();

  static const _channel = MethodChannel('wtf.sono/device');

  Future<List<ExitRecord>> exitRecords() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object>>(
        'getExitReasons',
      );
      return raw?.map(ExitRecord.fromMap).toList() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, Object?>> deviceInfo() async {
    if (!Platform.isAndroid) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'getDeviceInfo',
      );
      return raw ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<String> report() async {
    final info = await PackageInfo.fromPlatform();
    final flavor = await BuildFlavor.current();
    final device = await deviceInfo();
    final records = await exitRecords();

    final b = StringBuffer()
      ..writeln('Sono diagnostics')
      ..writeln('generated ${_stamp(DateTime.now())}')
      ..writeln()
      ..writeln('== app ==')
      ..writeln('version      ${info.version} (${info.buildNumber})')
      ..writeln('package      ${info.packageName}')
      ..writeln('flavor       ${flavor.name}')
      ..writeln('current rss  ${_mbFromBytes(ProcessInfo.currentRss)}')
      ..writeln('peak rss     ${_mbFromBytes(ProcessInfo.maxRss)}')
      ..writeln();

    if (device.isEmpty) {
      b
        ..writeln('== device ==')
        ..writeln('unavailable on this platform')
        ..writeln();
    } else {
      b
        ..writeln('== device ==')
        ..writeln(
          'model        ${device['manufacturer']} ${device['model']} '
          '(${device['device']})',
        )
        ..writeln(
          'android      ${device['androidRelease']} '
          '(sdk ${device['sdkInt']})',
        )
        ..writeln('total ram    ${_mbFromBytes(device['totalMem'] as num?)}')
        ..writeln('low ram      ${_flag(device['isLowRamDevice'])}')
        ..writeln(
          'heap limit   ${device['memoryClass']} MB, '
          'large ${device['largeMemoryClass']} MB',
        )
        ..writeln('bg restricted ${_flag(device['backgroundRestricted'])}')
        ..writeln(
          'doze exempt  ${_flag(device['ignoringBatteryOptimizations'])}',
        )
        ..writeln('fingerprint  ${device['fingerprint']}')
        ..writeln();
    }

    b.writeln('== exits (${records.length}) ==');
    if (records.isEmpty) {
      b.writeln('none recorded');
      return b.toString();
    }

    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final signal = r.signalName;
      b
        ..writeln('#$i  ${_stamp(r.timestamp)}  pid ${r.pid}')
        ..writeln(
          '    reason      ${r.reason} ${r.reasonName}'
          '${signal != null ? ' ($signal)' : ' (status ${r.status})'}',
        )
        ..writeln('    importance  ${r.importance} ${r.importanceName}')
        ..writeln(
          '    memory      pss ${_mbFromKb(r.pss)}, rss ${_mbFromKb(r.rss)}',
        )
        ..writeln('    description ${r.description ?? 'none'}');
      if (r.trace != null) {
        b
          ..writeln('    trace')
          ..writeln(r.trace);
      }
      b.writeln();
    }

    return b.toString();
  }
}
