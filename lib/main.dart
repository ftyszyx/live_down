import 'package:flutter/material.dart';
import 'package:live_down/core/configs/local_setting.dart';
import 'package:window_manager/window_manager.dart';
import 'package:live_down/app.dart';
import 'package:live_down/core/configs/app_config.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/features/download/download_repository.dart';
import 'package:live_down/features/download/services/download_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await AppConfig.initialize();
  await logger.initialize();
  await LocalSetting.initialize();
  logger.setLevel(LocalSetting.instance.logLevel);
  logger.i('App config loaded.');
  final downloadManager = DownloadManagerService();
  final downloadRepository = DownloadRepository(
    downloadManager: downloadManager,
  );

  runApp(MyApp( downloadRepository: downloadRepository));
}
