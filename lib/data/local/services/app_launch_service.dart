import '../db/db_service.dart';
import '../db/table_names.dart';
import 'block_instance_service.dart';

class AppLaunchService {
  AppLaunchService._();

  static final AppLaunchService instance = AppLaunchService._();

  Future<int> getOrCreateStarterBlockInstance({
    required String userId,
    String blockKey = 'starter_block',
  }) async {
    final db = await DbService.instance.database;

    final existing = await db.rawQuery(
      '''
      SELECT bi.id
      FROM ${TableNames.blockInstances} bi
      INNER JOIN ${TableNames.blockTemplates} bt
        ON bt.id = bi.block_template_id
      WHERE bi.user_id = ?
        AND bt.block_key = ?
        AND bi.status IN ('active', 'not_started')
      ORDER BY bi.id DESC
      LIMIT 1
      ''',
      [userId, blockKey],
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    return BlockInstanceService.instance.createBlockInstanceFromBlockKey(
      userId: userId,
      blockKey: blockKey,
    );
  }
}