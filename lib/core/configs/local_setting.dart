
import 'dart:convert';
import 'dart:io';

import 'package:live_down/core/services/logger_service.dart';
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

   static late LocalSetting _instance;

   LocalSetting._internal() : _logLevel = LogLevel.info, _saveDir = '<downloads>';

   static LocalSetting get instance => _instance ;

   static Future<void> initialize() async {
    // 读取配置文件from  user folder
    var userFolder=await getApplicationDocumentsDirectory();
    var appConfigPath=p.join(userFolder.path, 'config.json');
    var logLevel=LogLevel.info;
    var saveDir='<downloads>';
    if(File(appConfigPath).existsSync()){
      //load config from file
      var configContent=File(appConfigPath).readAsStringSync();
      var config=json.decode(configContent);
      if(config['log_level']!=null){
        logLevel=LogLevel.values.firstWhere((e) => e.name == config['log_level'],orElse: ()=>LogLevel.info);
      }
      if(config['save_dir']!=null){
        saveDir=config['save_dir'];
      }
    }
    _instance = LocalSetting._internal();
    _instance._logLevel=logLevel;
    _instance._saveDir=saveDir;
    _instance._appConfigPath=appConfigPath;
   }

   void save(){
    var config=json.encode({'log_level': _logLevel.name, 'save_dir': _saveDir});
    File(_appConfigPath).writeAsStringSync(config);
   }

}