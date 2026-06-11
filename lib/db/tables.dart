import 'package:drift/drift.dart';

class Artists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get favoritedAt => dateTime().nullable()();
}

class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get displayTitle => text().nullable()();
  IntColumn get artistId => integer().references(Artists, #id)();
  BlobColumn get cover => blob().nullable()();
  DateTimeColumn get favoritedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {title, artistId},
  ];
}

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get title => text()();
  IntColumn get duration => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  TextColumn get genre => text().nullable()();
  DateTimeColumn get releaseDate => dateTime().nullable()();
  IntColumn get albumId => integer().nullable().references(
    Albums,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get artistId => integer().nullable().references(
    Artists,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get displayArtist => text().nullable()();
  DateTimeColumn get likedAt => dateTime().nullable()();

  /// file mtime in ms, paired with fileSize as scan fingerprint
  /// null until song is touched by a (sono_query) v0.7.0+ scan
  IntColumn get mtimeMs => integer().nullable()();
  IntColumn get fileSize => integer().nullable()();
}

class LyricsCache extends Table {
  IntColumn get songId =>
      integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  TextColumn get versionsJson => text()();
  IntColumn get selectedIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {songId};
}

/// Key-value store for app settings (EQ, playback state, prefernces, etc.)
class Settings extends Table {
  TextColumn get settingKey => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

abstract class SongWithArtistView extends View {
  Songs get songs;
  Artists get artists;

  Expression<String> get artistName => artists.name;

  @override
  Query as() =>
      select([
        songs.id,
        songs.path,
        songs.title,
        songs.duration,
        songs.genre,
        songs.releaseDate,
        songs.albumId,
        songs.artistId,
        songs.displayArtist,
        songs.likedAt,
        artistName,
      ]).from(songs).join([
        leftOuterJoin(artists, artists.id.equalsExp(songs.artistId)),
      ]);
}

abstract class AlbumWithArtistView extends View {
  Albums get albums;
  Artists get artists;

  Expression<String> get artistName => artists.name;

  @override
  Query as() =>
      select([
        albums.id,
        albums.title,
        albums.artistId,
        albums.favoritedAt,
        artistName,
      ]).from(albums).join([
        leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
      ]);
}

/// Local accounts
class Profiles extends Table {
  //singleton: always 1, enforces column as primary key
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get username => text()();
  BlobColumn get avatar => blob().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Playlists
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class PlaylistSongs extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId =>
      integer().references(Songs, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId, songId};
}
