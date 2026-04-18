import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'schema_sql.dart';
import 'table_names.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, SchemaSql.dbName);

    return openDatabase(
      path,
      version: SchemaSql.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in SchemaSql.createStatements) {
          await db.execute(statement);
        }

        for (final statement in SchemaSql.indexStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE ${TableNames.badgeAwards} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              badge_key TEXT NOT NULL,
              user_id TEXT NOT NULL,
              awarded_at TEXT NOT NULL,
              source_type TEXT NOT NULL,
              source_id TEXT NOT NULL,
              block_instance_id INTEGER,
              metadata_json TEXT,
              FOREIGN KEY (block_instance_id) REFERENCES ${TableNames.blockInstances}(id)
            )
          ''');

          await db.execute(
            'CREATE INDEX idx_badge_awards_user_id ON ${TableNames.badgeAwards}(user_id)',
          );
          await db.execute(
            'CREATE INDEX idx_badge_awards_block_instance_id ON ${TableNames.badgeAwards}(block_instance_id)',
          );
          await db.execute(
            'CREATE INDEX idx_badge_awards_user_badge_key ON ${TableNames.badgeAwards}(user_id, badge_key)',
          );
        }
      },
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, SchemaSql.dbName);
    await databaseFactory.deleteDatabase(path);
  }

  Future<void> debugPrintSeedState() async {
    final db = await database;

    final muscleRows = await db.query(TableNames.muscleGroups);
    final liftRows = await db.query(TableNames.liftCatalog);
    final liftMuscleRows = await db.query(TableNames.liftCatalogMuscleGroups);
    final blockRows = await db.query(TableNames.blockTemplates);
    final workoutRows = await db.query(TableNames.workoutTemplates);
    final workoutLiftRows = await db.query(TableNames.workoutTemplateLifts);

    print('MUSCLE GROUP COUNT: ${muscleRows.length}');
    print('LIFT COUNT: ${liftRows.length}');
    print('LIFT MUSCLE COUNT: ${liftMuscleRows.length}');
    print('BLOCK TEMPLATE COUNT: ${blockRows.length}');
    print('WORKOUT TEMPLATE COUNT: ${workoutRows.length}');
    print('WORKOUT TEMPLATE LIFT COUNT: ${workoutLiftRows.length}');
  }
}