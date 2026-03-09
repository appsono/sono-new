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
