import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sono/services/changelog/changelog_service.dart';

const _wrapped = '''
# Changelog

## [Unreleased]

Nothing yet.

## [0.11.0+12] - 2026-07-22

(unreleased until new translation updates roll in)

### Added

- Added a new system theme mode that follows the device brightness,
  allowing system light/dark schedules to apply to Sono. Fresh installs
  default to it
- Added EQ presets

### Fixed

- Fixed a black flash when opening subpages in light mode, caused by the
  page transition scrim using a translucent overlay colour

## [0.10.1+11] - 2026-07-20

### Fixed

- Older release, should not be parsed
''';

const _unwrapped = '''
# Changelog

## [0.11.0+12] - 2026-07-22

### Added

- Added a new system theme mode that follows the device brightness, allowing system light/dark schedules to apply to Sono. Fresh installs default to it
- Added EQ presets
''';

void main() {
  group('wrapped entries', () {
    test('continuation lines rejoin into one entry', () {
      final r = ChangelogService.parse(_wrapped)!;
      final added = r.sections.firstWhere((s) => s.title == 'Added');

      expect(added.entries, hasLength(2));
      expect(added.entries.first, endsWith('Fresh installs default to it'));
      expect(added.entries.first, contains('light/dark schedules'));
    });

    test('wrapping does not change the parsed result', () {
      final a = ChangelogService.parse(_wrapped)!;
      final b = ChangelogService.parse(_unwrapped)!;
      final aAdded = a.sections.firstWhere((s) => s.title == 'Added');
      final bAdded = b.sections.firstWhere((s) => s.title == 'Added');

      expect(aAdded.entries, bAdded.entries);
    });

    test('a wrapped entry is not cut at the first line', () {
      final r = ChangelogService.parse(_wrapped)!;
      final fixed = r.sections.firstWhere((s) => s.title == 'Fixed');

      expect(fixed.entries.single, endsWith('translucent overlay colour'));
    });
  });

  group('release selection', () {
    test('skips unreleased and stops before the previous release', () {
      final r = ChangelogService.parse(_wrapped)!;

      expect(r.version, '0.11.0+12');
      expect(r.date, '2026-07-22');
      expect(
        r.sections.expand((s) => s.entries),
        isNot(contains(contains('Older release'))),
      );
    });

    test('prose under the version header is not captured', () {
      final r = ChangelogService.parse(_wrapped)!;

      expect(
        r.sections.expand((s) => s.entries),
        isNot(contains(contains('translation updates roll in'))),
      );
    });
  });

  group('shipped changelog', () {
    test('every entry survives parsing', () {
      final raw = File('CHANGELOG.md').readAsStringSync();
      final r = ChangelogService.parse(raw);
      expect(r, isNotNull);

      final lines = raw.split('\n');
      final start = lines.indexWhere(
        (l) => l.startsWith('## [') && !l.contains('[Unreleased]'),
      );
      final rest = lines.skip(start + 1);
      final end = rest.toList().indexWhere((l) => l.startsWith('## ['));
      final block = rest.take(end == -1 ? rest.length : end);
      final bullets = block.where((l) => l.startsWith('- ')).length;

      final parsed = r!.sections.fold<int>(0, (n, s) => n + s.entries.length);
      expect(parsed, bullets);
    });

    test('no entry ends mid sentence', () {
      final raw = File('CHANGELOG.md').readAsStringSync();
      final r = ChangelogService.parse(raw)!;

      for (final s in r.sections) {
        for (final e in s.entries) {
          expect(e.trim(), isNot(endsWith(',')));
          expect(e.trim(), isNot(endsWith('the')));
          expect(e.trim(), isNot(endsWith('and')));
        }
      }
    });
  });
}
