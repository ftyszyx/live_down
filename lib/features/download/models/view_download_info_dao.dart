import 'package:live_down/core/services/database_service.dart';
import 'package:live_down/features/download/models/download_task.dart';

class ViewDownloadInfoDao {
  final dbProvider = DatabaseService.instance;

  Future<int> addTask(ViewDownloadInfo task) async {
    final db = await dbProvider.database;
    return await db.insert('tasks', task.toDbMap());
  }

  Future<List<ViewDownloadInfo>> getAllTasks() async {
    final db = await dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return List.generate(maps.length, (i) {
      return ViewDownloadInfo.fromDbMap(maps[i]);
    });
  }

  Future<int> updateTask(ViewDownloadInfo task) async {
    final db = await dbProvider.database;
    return await db .update('tasks', task.toDbMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await dbProvider.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
} 