
import 'dart:convert';
import 'dart:io';

import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalSetting {
  LogLevel _logLevel;
  LogLevel get logLevel => _logLevel;

  late String _appConfigPath;
  String get appConfigPath => _appConfigPath;

  set logLevel(LogLevel value) {
    _logLevel = value;
    save();
  }

  String _saveDir;
  String get saveDir => _saveDir;

  set saveDir(String value) {
    _saveDir = value;
    save();
  }

  List<ViewDownloadInfo> _tasks = [];
  List<ViewDownloadInfo> get tasks => _tasks;

  static late LocalSetting _instance;

  LocalSetting._internal()
      : _logLevel = LogLevel.info,
        _saveDir = '<downloads>';

  static LocalSetting get instance => _instance;

  static Future<void> initialize() async {
    // 读取配置文件from  user folder
    var userFolder = await getApplicationDocumentsDirectory();
    var appConfigPath = p.join(userFolder.path, 'config.json');
    var logLevel = LogLevel.info;
    var saveDir = '<downloads>';
    List<ViewDownloadInfo> tasks = [];

    if (File(appConfigPath).existsSync()) {
      //load config from file
      var configContent = File(appConfigPath).readAsStringSync();
      var config = json.decode(configContent);
      if (config['log_level'] != null) {
        logLevel = LogLevel.values.firstWhere(
            (e) => e.name == config['log_level'],
            orElse: () => LogLevel.info);
      }
      if (config['save_dir'] != null) {
        saveDir = config['save_dir'];
      }
      if (config['tasks'] != null) {
        for(var taskJson in config['tasks']){
          try{
            tasks.add(ViewDownloadInfo.fromJson(taskJson));
          }catch(e,s){
            logger.w('load task error',error: e,stackTrace: s);
          } 
        }
      }
    }
    _instance = LocalSetting._internal();
    _instance._logLevel = logLevel;
    _instance._saveDir = saveDir;
    _instance._appConfigPath = appConfigPath;
    _instance._tasks = tasks;
  }

  void save() {
    var config = json.encode({
      'log_level': _logLevel.name,
      'save_dir': _saveDir,
      'tasks': _tasks.map((task) => task.toJson()).toList()
    });
    File(_appConfigPath).writeAsStringSync(config);
  }

  void addTask(ViewDownloadInfo task) {
    if (_tasks.any((t) => t.id == task.id )) {
      return;
    }
    _tasks.add(task);
    save();
  }

  void updateTask(ViewDownloadInfo task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      save();
    }
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    save();
  }

  ViewDownloadInfo? getTaskByUrl(String url) {
    try{
      return _tasks.firstWhere((t) => t.downloadUrl == url);
    }catch(e){
      return null;
    }
  }

  ViewDownloadInfo? getTaskById(String id) {
    try{
      return _tasks.firstWhere((t) => t.id == id);
    }catch(e){
      return null;
    }
  }
}