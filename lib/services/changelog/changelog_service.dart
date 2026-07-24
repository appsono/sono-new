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

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show visibleForTesting;

export 'package:sono/services/changelog/models.dart';
import 'package:sono/services/changelog/models.dart';

/// Reads bundled changelog-file and extracts latest release block
class ChangelogService {
  static const _assetPath = 'CHANGELOG.md';

  static final _headerRe = RegExp(r'^##\s+(.*)$'); // ## ...
  static final _versionRe = RegExp(r'\[([^\]]+)\]'); // first [...]
  static final _dateRe = RegExp(r'(\d{4}-\d{2}-\d{2})');
  static final _sectionRe = RegExp(r'^###\s+(.*)$');
  static final _bulletRe = RegExp(r'^[*-]\s+(.*)$');
  static final _linkRe = RegExp(r'\[([^\]]+)\]\([^)]*\)');

  static Future<ChangelogRelease?> loadLatest() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(_assetPath);
    } catch (_) {
      return null;
    }
    return _parseLatest(raw);
  }

  static ChangelogRelease? _parseLatest(String raw) {
    final lines = raw.split('\n');

    //find first level-2 header skip [Unreleased]
    var i = 0;
    String? header;
    while (i < lines.length) {
      final m = _headerRe.firstMatch(lines[i].trimRight());
      if (m != null) {
        final h = m.group(1)!.trim();
        final v = _versionRe.firstMatch(h)?.group(1)?.trim();
        if (v != null && v.toLowerCase() != 'unreleased') {
          header = h;
          i++;
          break;
        }
      }
      i++;
    }
    if (header == null) return null;

    final version =
        _versionRe.firstMatch(header)?.group(1)?.trim() ??
        header.split(RegExp(r'\s+')).first.replaceAll(RegExp(r'[\[\]]'), '');
    final date = _dateRe.firstMatch(header)?.group(1);

    final sections = <ChangelogSection>[];
    String? title;
    var entries = <String>[];

    void flush() {
      if (title != null && entries.isNotEmpty) {
        sections.add(ChangelogSection(title!, entries));
      }
      title = null;
      entries = <String>[];
    }

    for (; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (_headerRe.hasMatch(line)) break; //next release == stop

      final sec = _sectionRe.firstMatch(line);
      if (sec != null) {
        flush();
        title = sec.group(1)!.trim();
        continue;
      }

      final bullet = _bulletRe.firstMatch(line.trimLeft());
      if (bullet != null && title != null) {
        entries.add(_clean(bullet.group(1)!));
      } else if (title != null &&
          entries.isNotEmpty &&
          line.trim().isNotEmpty) {
        //wrapped continuation of previous bullet
        entries[entries.length - 1] = _clean('${entries.last} ${line.trim()}');
      }
    }
    flush();

    return ChangelogRelease(version: version, date: date, sections: sections);
  }

  /// markdown link -> label, drop bold/italic markers and inline code
  static String _clean(String s) {
    var out = s.replaceAllMapped(_linkRe, (m) => m.group(1)!);
    out = out.replaceAll(RegExp(r'\*\*|__'), '');
    out = out.replaceAll('`', '');
    return out.trim();
  }

  /// ==== testing ====
  @visibleForTesting
  static ChangelogRelease? parse(String raw) => _parseLatest(raw);
}
