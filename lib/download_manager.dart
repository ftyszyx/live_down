import 'dart:io';
import 'package:live_down/main.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'logger.dart';

class DownloadManager {
  // Using a singleton pattern to ensure we have only one instance of the manager.
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<int, Process> _activeProcesses = {};

  Future<void> startDownload(int taskId, String m3u8Url, String title) async {
    if (_activeProcesses.containsKey(taskId)) {
      logger.w('Task $taskId is already running.');
      return;
    }

    try {
      // --- This logic is moved from DownloaderService ---
      final downloadsPath = await getDownloadsDirectory();
      if (downloadsPath == null) {
        throw Exception('无法获取下载目录');
      }
      final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = path.join(appConfig.saveDir, '$sanitizedTitle.mp4');
      logger.i('Task $taskId will be saved to: $savePath');

      final String exeDir = path.dirname(Platform.resolvedExecutable);
      final String ffmpegPath = path.join(
          exeDir, 'data', 'flutter_assets', 'assets', 'ffmpeg', 'ffmpeg.exe');

      if (!await File(ffmpegPath).exists()) {
        throw Exception('打包的 ffmpeg.exe 未找到，路径: $ffmpegPath');
      }
      // --- End of moved logic ---

      final process = await Process.start(
        ffmpegPath,
        [
          '-protocol_whitelist', 'file,http,https,tcp,tls,crypto',
          '-i', m3u8Url,
          '-c', 'copy',
          '-bsf:a', 'aac_adtstoasc',
          savePath,
        ],
      );

      _activeProcesses[taskId] = process;
      logger.i('Started download for task $taskId. Process ID: ${process.pid}');

      // Handle process completion
      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        logger.i('Task $taskId finished successfully.');
      } else {
        logger.e('Task $taskId failed with exit code $exitCode.');
        // You might want to handle stderr here to get error details
      }
      _activeProcesses.remove(taskId);

    } catch (e) {
      logger.e('Error starting download for task $taskId', error: e);
      _activeProcesses.remove(taskId);
      // Re-throw the exception so the UI can be notified
      rethrow;
    }
  }

  void stopDownload(int taskId) {
    if (_activeProcesses.containsKey(taskId)) {
      final process = _activeProcesses[taskId];
      final success = process?.kill();
      logger.i('Stopping download for task $taskId. Success: $success');
      _activeProcesses.remove(taskId);
    } else {
      logger.w('No active download found for task $taskId to stop.');
    }
  }
} 