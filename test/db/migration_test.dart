import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sono/db/database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sono_migration');
    file = File('${dir.path}/sono.db');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<void> downgradeTo18({Set<String> keep = const {}}) async {
    final db = SonoDatabase.forTesting(NativeDatabase(file));
    for (final table in [
      'discord_covers',
      'scrobbles',
      'song_artists',
      'plays',
    ]) {
      if (!keep.contains(table)) {
        await db.customStatement('DROP TABLE $table');
      }
    }
    await db.customStatement('PRAGMA user_version = 18');
    await db.close();
  }

  Future<void> expectCurrentSchema() async {
    final db = SonoDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
    expect(await db.select(db.plays).get(), isEmpty);
    expect(await db.select(db.scrobbles).get(), isEmpty);
    expect(await db.select(db.discordCovers).get(), isEmpty);
  }

  test('upgrades from 0.12.x', () async {
    await downgradeTo18();
    await expectCurrentSchema();
  });

  //0.13.0 left these behind when the upgrade failed
  test('upgrades a half migrated 0.12.x database', () async {
    await downgradeTo18(keep: {'plays', 'song_artists'});
    await expectCurrentSchema();
  });
}
