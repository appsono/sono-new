import 'package:flutter_test/flutter_test.dart';
import 'package:sono/services/migration/legacy_settings_map.dart';

LegacySettingRow row(String category, String key, String value) =>
    (category: category, key: key, value: value);

void main() {
  group('direct mappings', () {
    test('theme mode index becomes a mode name', () {
      final m = LegacySettingsMap.map([row('ui', 'theme_mode', '2')]);
      expect(m.direct['theme.mode'], 'dark');
      expect(m.parked, isEmpty);
    });

    test('theme mode 0 is system', () {
      final m = LegacySettingsMap.map([row('ui', 'theme_mode', '0')]);
      expect(m.direct['theme.mode'], 'system');
    });

    test('out of range theme mode is parked, not guessed', () {
      final m = LegacySettingsMap.map([row('ui', 'theme_mode', '7')]);
      expect(m.direct, isEmpty);
      expect(m.parked, hasLength(1));
    });

    test('excluded folders pass through as a json list', () {
      const raw = '["/sdcard/Ringtones","/sdcard/Podcasts"]';
      final m = LegacySettingsMap.map([
        row('library', 'excluded_folders', raw),
      ]);
      expect(m.direct['scan.excludedPaths'], raw);
    });

    test('excluded folders that are not a list are parked', () {
      final m = LegacySettingsMap.map([
        row('library', 'excluded_folders', '"/sdcard/Ringtones"'),
      ]);
      expect(m.direct, isEmpty);
      expect(m.parked, hasLength(1));
    });

    test('speed and pitch decode json then restringify', () {
      final m = LegacySettingsMap.map([
        row('playback', 'speed', '1.25'),
        row('playback', 'pitch', '0.9'),
      ]);
      expect(m.direct['fx.speed'], '1.25');
      expect(m.direct['fx.pitch'], '0.9');
    });

    test('integer speed becomes a double string', () {
      final m = LegacySettingsMap.map([row('playback', 'speed', '1')]);
      expect(m.direct['fx.speed'], '1.0');
    });
  });

  group('parked', () {
    test('roadmap keys are held verbatim', () {
      final m = LegacySettingsMap.map([
        row('playback', 'crossfade_enabled', 'true'),
        row('playback', 'crossfade_duration', '5'),
      ]);
      expect(m.direct, isEmpty);
      expect(m.parked, hasLength(2));
      expect(m.parked.first.value, 'true');
    });

    test('unknown keys are parked rather than lost', () {
      final m = LegacySettingsMap.map([row('ui', 'some_future_thing', '"x"')]);
      expect(m.parked, hasLength(1));
    });

    test('a key parked under one category does not shadow another', () {
      final m = LegacySettingsMap.map([
        row('playback', 'crossfade_enabled', 'true'),
        row('somethingelse', 'crossfade_enabled', 'false'),
      ]);
      expect(m.parked, hasLength(2));
    });
  });

  group('dropped', () {
    test('dead features are discarded', () {
      final m = LegacySettingsMap.map([
        row('analytics', 'enabled', 'true'),
        row('scrobbling', 'api_mode_prod', 'true'),
        row('playback', 'background_playback', 'true'),
        row('system', 'migration_version', '8'),
        row('ui', 'accent_color', '4294901760'),
        row('ui', 'experimental_themes', 'false'),
        row('developer', 'experimental_features', 'false'),
      ]);
      expect(m.direct, isEmpty);
      expect(m.parked, isEmpty);
    });
  });

  group('robustness', () {
    test('empty input yields empty output', () {
      final m = LegacySettingsMap.map([]);
      expect(m.direct, isEmpty);
      expect(m.parked, isEmpty);
    });

    test('malformed json is parked, never thrown on', () {
      final m = LegacySettingsMap.map([
        row('playback', 'speed', 'not json at all'),
      ]);
      expect(m.direct, isEmpty);
      expect(m.parked, hasLength(1));
    });
  });
}
