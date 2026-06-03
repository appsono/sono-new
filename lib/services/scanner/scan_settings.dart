import 'dart:convert';
import 'package:sono/db/database.dart';
import 'package:sono_query/sono_query.dart';
import 'package:sono/services/scanner/scan_service.dart';

/// Persists scan config in settings key-value table
///
/// Keys used:
///   scan.excludedPaths > JSON list of path strings
///   scan.additionalPaths > JSON list of path strings
///   scan.minDurationMs > int as string
///   scan.artistDelimiters > JSON list of delimiter strings
///   scan.excludedArtists > JSON list of artist name strings
///   scan.artistParserOn > "true" / "false"
class ScanSettings {
  final SonoDatabase db;

  ScanSettings(this.db);

  // ==== keys ====
  static const _kAlbumGrouping = 'library.albumGrouping';
  static const _kExcludedPaths = 'scan.excludedPaths';
  static const _kAdditionalPaths = 'scan.additionalPaths';
  static const _kMinDurationMs = 'scan.minDurationMs';
  static const _kArtistDelimiters = 'scan.artistDelimiters';
  static const _kExcludedArtists = 'scan.excludedArtists';
  static const _kArtistParserOn = 'scan.artistParserOn';

  /// Loads a [ScanConfig] from persisted settings
  Future<ScanConfig> load() async {
    final all = await db.getAllSettings();

    final excludedPaths = _decodeStringList(all[_kExcludedPaths]);
    final additionalPaths = _decodeStringList(all[_kAdditionalPaths]);

    final minMs = all[_kMinDurationMs];
    final minDuration = minMs != null
        ? Duration(milliseconds: int.tryParse(minMs) ?? 0)
        : null;

    final parserOn = all[_kArtistParserOn] == 'true';
    ArtistParserConfig? artistParser;
    if (parserOn) {
      final delimiters = _decodeStringList(all[_kArtistDelimiters]);
      final excludedArtists = _decodeStringList(all[_kExcludedArtists]);
      artistParser = ArtistParserConfig(
        delimiters: delimiters.isNotEmpty
            ? delimiters
            : ArtistParserConfig.defaultDelimiters,
        excludedArtists: excludedArtists,
      );
    }

    return ScanConfig(
      excludedPaths: excludedPaths,
      additionalPaths: additionalPaths,
      minDuration: minDuration,
      artistParser: artistParser,
    );
  }

  /// Persists a [ScanConfig] to settings table
  Future<void> save(ScanConfig config) async {
    await db.transaction(() async {
      await db.setSetting(_kExcludedPaths, jsonEncode(config.excludedPaths));
      await db.setSetting(
        _kAdditionalPaths,
        jsonEncode(config.additionalPaths),
      );
    });

    if (config.minDuration != null) {
      await db.setSetting(
        _kMinDurationMs,
        config.minDuration!.inMilliseconds.toString(),
      );
    } else {
      await db.removeSetting(_kMinDurationMs);
    }

    final parserOn = config.artistParser != null;
    await db.setSetting(_kArtistParserOn, parserOn.toString());

    if (parserOn) {
      await db.setSetting(
        _kArtistDelimiters,
        jsonEncode(config.artistParser!.delimiters),
      );
      await db.setSetting(
        _kExcludedArtists,
        jsonEncode(config.artistParser!.excludedArtists),
      );
    }
  }

  static List<String> _decodeStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Loads album grouping mode, defaults to tag
  Future<AlbumGrouping> loadAlbumGrouping() async {
    final all = await db.getAllSettings();
    return all[_kAlbumGrouping] == 'folder'
        ? AlbumGrouping.folder
        : AlbumGrouping.tag;
  }

  Future<void> saveAlbumGrouping(AlbumGrouping grouping) => db.setSetting(
    _kAlbumGrouping,
    grouping == AlbumGrouping.folder ? 'folder' : 'tag',
  );
}
