import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class AppConfig {
  final String appTitle;
  final String saveDir;

  AppConfig({
    required this.appTitle,
    required this.saveDir,
  });

  static Future<AppConfig> load() async {
    final yamlString = await rootBundle.loadString('assets/app_config.yaml');
    final dynamic yamlMap = loadYaml(yamlString);

    return AppConfig(
      appTitle: yamlMap['app_title'],
      saveDir: yamlMap['save_dir'],
    );
  }
}