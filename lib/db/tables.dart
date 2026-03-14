import 'package:drift/drift.dart';

class Artists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get artistId => integer().references(Artists, #id)();
  BlobColumn get cover => blob().nullable()();

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
  TextColumn get genre => text().nullable()();
  DateTimeColumn get releaseDate => dateTime().nullable()();
  IntColumn get albumId => integer().nullable().references(Albums, #id)();
  IntColumn get artistId => integer().nullable().references(Artists, #id)();
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
        albums.cover,
        artistName,
      ]).from(albums).join([
        leftOuterJoin(artists, artists.id.equalsExp(albums.artistId)),
      ]);
}
