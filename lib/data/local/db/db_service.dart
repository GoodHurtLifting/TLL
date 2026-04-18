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
        // Add migrations here later.
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