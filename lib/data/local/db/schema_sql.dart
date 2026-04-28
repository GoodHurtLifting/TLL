import 'table_names.dart';

class SchemaSql {
  static const int dbVersion = 4;
  static const String dbName = 'tll.db';

  static const supportedScoreTypes = ['multiplier', 'bodyweight'];
  static const supportedInputModes = ['standard', 'per_side'];

  static List<String> createStatements = [
    '''
    CREATE TABLE ${TableNames.liftCatalog} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lift_key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      video_url TEXT,
      default_rep_scheme TEXT,
      lift_info TEXT,
      score_type TEXT NOT NULL,
      input_mode TEXT NOT NULL DEFAULT 'standard',
      created_at TEXT,
      updated_at TEXT
    )
    ''',
    '''
    CREATE TABLE ${TableNames.muscleGroups} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      muscle_key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT
    )
    ''',
    '''
    CREATE TABLE ${TableNames.liftCatalogMuscleGroups} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lift_catalog_id INTEGER NOT NULL,
      muscle_group_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (lift_catalog_id) REFERENCES ${TableNames.liftCatalog}(id),
      FOREIGN KEY (muscle_group_id) REFERENCES ${TableNames.muscleGroups}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.blockTemplates} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      block_key TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      description TEXT,
      category TEXT NOT NULL,
      difficulty TEXT,
      num_weeks INTEGER NOT NULL,
      schedule_type TEXT NOT NULL,
      workouts_per_week INTEGER,
      total_workout_slots INTEGER,
      is_custom INTEGER NOT NULL DEFAULT 0,
      owner_user_id TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
    ''',
    '''
    CREATE TABLE ${TableNames.workoutTemplates} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_key TEXT NOT NULL UNIQUE,
      block_template_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      workout_type TEXT,
      sequence_index INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (block_template_id) REFERENCES ${TableNames.blockTemplates}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.workoutTemplateLifts} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_template_id INTEGER NOT NULL,
      lift_catalog_id INTEGER NOT NULL,
      sequence_index INTEGER NOT NULL,
      rep_scheme TEXT NOT NULL,
      lift_info TEXT,
      score_type TEXT,
      score_multiplier REAL,
      score_multiplier_mode TEXT,
      input_mode TEXT,
      reference_source TEXT,
      reference_lift_key TEXT,
      percent_value REAL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (workout_template_id) REFERENCES ${TableNames.workoutTemplates}(id),
      FOREIGN KEY (lift_catalog_id) REFERENCES ${TableNames.liftCatalog}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.blockInstances} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      block_template_id INTEGER NOT NULL,
      run_number INTEGER NOT NULL,
      title_snapshot TEXT NOT NULL,
      started_at TEXT,
      completed_at TEXT,
      status TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (block_template_id) REFERENCES ${TableNames.blockTemplates}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.workoutInstances} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      block_instance_id INTEGER NOT NULL,
      workout_template_id INTEGER NOT NULL,
      workout_slot_index INTEGER NOT NULL,
      week_index INTEGER NOT NULL,
      day_label TEXT,
      title_snapshot TEXT NOT NULL,
      started_at TEXT,
      completed_at TEXT,
      status TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (block_instance_id) REFERENCES ${TableNames.blockInstances}(id),
      FOREIGN KEY (workout_template_id) REFERENCES ${TableNames.workoutTemplates}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.liftInstances} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_instance_id INTEGER NOT NULL,
      workout_template_lift_id INTEGER NOT NULL,
      sequence_index INTEGER NOT NULL,
      lift_name_snapshot TEXT NOT NULL,
      rep_scheme_snapshot TEXT NOT NULL,
      lift_info_snapshot TEXT,
      score_type_snapshot TEXT NOT NULL,
      score_multiplier_snapshot REAL,
      input_mode_snapshot TEXT NOT NULL DEFAULT 'standard',
      reference_source_snapshot TEXT,
      reference_lift_key_snapshot TEXT,
      percent_value_snapshot REAL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (workout_instance_id) REFERENCES ${TableNames.workoutInstances}(id),
      FOREIGN KEY (workout_template_lift_id) REFERENCES ${TableNames.workoutTemplateLifts}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.liftLogs} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lift_instance_id INTEGER NOT NULL,
      set_index INTEGER NOT NULL,
      reps INTEGER,
      weight REAL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (lift_instance_id) REFERENCES ${TableNames.liftInstances}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.liftTotals} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lift_instance_id INTEGER NOT NULL UNIQUE,
      total_reps INTEGER NOT NULL DEFAULT 0,
      total_workload REAL NOT NULL DEFAULT 0,
      total_score REAL NOT NULL DEFAULT 0,
      updated_at TEXT,
      FOREIGN KEY (lift_instance_id) REFERENCES ${TableNames.liftInstances}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.workoutTotals} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_instance_id INTEGER NOT NULL UNIQUE,
      total_workload REAL NOT NULL DEFAULT 0,
      workout_score REAL NOT NULL DEFAULT 0,
      completed_lift_count INTEGER NOT NULL DEFAULT 0,
      total_lift_count INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT,
      FOREIGN KEY (workout_instance_id) REFERENCES ${TableNames.workoutInstances}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.blockTotals} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      block_instance_id INTEGER NOT NULL UNIQUE,
      total_workload REAL NOT NULL DEFAULT 0,
      block_score REAL NOT NULL DEFAULT 0,
      completed_workout_count INTEGER NOT NULL DEFAULT 0,
      total_workout_count INTEGER NOT NULL DEFAULT 0,
      training_days INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT,
      FOREIGN KEY (block_instance_id) REFERENCES ${TableNames.blockInstances}(id)
    )
    ''',
    '''
    CREATE TABLE ${TableNames.userStatsCache} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL UNIQUE,
      total_blocks_completed INTEGER NOT NULL DEFAULT 0,
      total_workouts_completed INTEGER NOT NULL DEFAULT 0,
      total_lbs_lifted REAL NOT NULL DEFAULT 0,
      updated_at TEXT
    )
    ''',
    '''
    CREATE TABLE ${TableNames.liftWeightPrCache} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      lift_key TEXT NOT NULL,
      heaviest_weight REAL NOT NULL DEFAULT 0,
      updated_at TEXT
    )
    ''',
    '''
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
    ''',

    '''
    CREATE TABLE ${TableNames.syncQueue} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      action TEXT NOT NULL,
      payload_json TEXT,
      status TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT
    )
    ''',
    '''
    CREATE TABLE ${TableNames.syncState} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL UNIQUE,
      value TEXT,
      updated_at TEXT
    )
    ''',
  ];

  static List<String> indexStatements = [
    'CREATE INDEX idx_workout_templates_block_template_id ON ${TableNames.workoutTemplates}(block_template_id)',
    'CREATE INDEX idx_workout_template_lifts_workout_template_id ON ${TableNames.workoutTemplateLifts}(workout_template_id)',
    'CREATE INDEX idx_workout_template_lifts_lift_catalog_id ON ${TableNames.workoutTemplateLifts}(lift_catalog_id)',
    'CREATE INDEX idx_block_instances_user_id ON ${TableNames.blockInstances}(user_id)',
    'CREATE INDEX idx_block_instances_block_template_id ON ${TableNames.blockInstances}(block_template_id)',
    'CREATE UNIQUE INDEX idx_block_instances_user_template_run ON ${TableNames.blockInstances}(user_id, block_template_id, run_number)',
    'CREATE INDEX idx_workout_instances_block_instance_id ON ${TableNames.workoutInstances}(block_instance_id)',
    'CREATE UNIQUE INDEX idx_workout_instances_block_slot ON ${TableNames.workoutInstances}(block_instance_id, workout_slot_index)',
    'CREATE INDEX idx_lift_instances_workout_instance_id ON ${TableNames.liftInstances}(workout_instance_id)',
    'CREATE UNIQUE INDEX idx_lift_instances_workout_sequence ON ${TableNames.liftInstances}(workout_instance_id, sequence_index)',
    'CREATE INDEX idx_lift_logs_lift_instance_id ON ${TableNames.liftLogs}(lift_instance_id)',
    'CREATE UNIQUE INDEX idx_lift_logs_lift_set ON ${TableNames.liftLogs}(lift_instance_id, set_index)',
    'CREATE UNIQUE INDEX idx_lift_weight_pr_cache_user_lift ON ${TableNames.liftWeightPrCache}(user_id, lift_key)',
    'CREATE INDEX idx_badge_awards_user_id ON ${TableNames.badgeAwards}(user_id)',
    'CREATE INDEX idx_badge_awards_block_instance_id ON ${TableNames.badgeAwards}(block_instance_id)',
    'CREATE INDEX idx_badge_awards_user_badge_key ON ${TableNames.badgeAwards}(user_id, badge_key)',
    'CREATE UNIQUE INDEX idx_sync_state_key ON ${TableNames.syncState}(key)',
    'CREATE INDEX idx_lift_catalog_muscle_groups_lift_catalog_id ON ${TableNames.liftCatalogMuscleGroups}(lift_catalog_id)',
    'CREATE INDEX idx_lift_catalog_muscle_groups_muscle_group_id ON ${TableNames.liftCatalogMuscleGroups}(muscle_group_id)',
    'CREATE UNIQUE INDEX idx_lift_catalog_muscle_groups_unique_role ON ${TableNames.liftCatalogMuscleGroups}(lift_catalog_id, muscle_group_id, role)',
  ];
}
