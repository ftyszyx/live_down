import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class AppConfig {
  final String appTitle;
  final String saveDir;

  // Private constructor
  AppConfig._internal({required this.appTitle, required this.saveDir});

  // Static instance with lazy initialization
  static late final AppConfig instance;

  // Asynchronous initialization method
  static Future<void> initialize() async {
    final configString = await rootBundle.loadString('assets/app_config.yaml');
    final config = loadYaml(configString);
    instance = AppConfig._internal(
      appTitle: config['app_title'] ?? 'Live Downloader',
      saveDir: config['save_dir'] ?? '<downloads>',
    );
  }
} 