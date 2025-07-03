import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:live_down/core/configs/app_config.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/core/services/path_service.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:path/path.dart' as path;

class DownloadProgressUpdate {
  final int taskId;
  final int bitSpeedPerSecond;
  final int progressCurrent;
  final int progressTotal;
  final DownloadStatus status;

  DownloadProgressUpdate({
    required this.taskId,
    required this.bitSpeedPerSecond,
    required this.progressCurrent,
    required this.progressTotal,
    required this.status,
  });
}

class DownloadTask{
  final int id;
  final String m3u8Url;
  final String title;
  final DownloadStatus status;
}

class DownloadManagerService {
  static final DownloadManagerService _instance = DownloadManagerService._internal();
  factory DownloadManagerService() => _instance;
  DownloadManagerService._internal();

  // final Map<int, Process> _activeMergeProcesses = {};
  // final Map<int, bool> _cancellationTokens = {};
  final Map<int,DownloadTask> _downloadTasks = {};
  final _progressController = StreamController<DownloadProgressUpdate>.broadcast();
  Stream<DownloadProgressUpdate> get progressStream => _progressController.stream;

  Future<void> addDownloadTask(int taskId, String m3u8Url, String title) async {
    late DownloadTask task;
    if (_downloadTasks.containsKey(taskId)){ 
      task = _downloadTasks[taskId]!;
      var status = task.status;
      if(status == DownloadStatus.downloading){
        logger.w('Task $taskId is already running.');
        return;
      }
      if(status == DownloadStatus.completed || status == DownloadStatus.merging){
        logger.w('Task $taskId is already completed.');
        return;
      }
    }
    else{
      task = DownloadTask(
        id: taskId,
        m3u8Url: m3u8Url,
        title: title,
        status: DownloadStatus.downloading,
      );
    _downloadTasks[taskId] = task;
    }
    task.status = DownloadStatus.downloading;
    final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String taskIdentifier = '$taskId-$sanitizedTitle';
    final tempDir = await PathService.getTaskTempPath(taskIdentifier);
    final absoluteSaveDir = await PathService.getAbsoluteSavePath(AppConfig.instance.saveDir);
    final finalSavePath = path.join(absoluteSaveDir, '$sanitizedTitle.mp4');
    task.tempDir = tempDir;
    task.finalSavePath = finalSavePath;
  }

  Future<void> startDownload2( int taskId, String m3u8Url, String title) async {
    final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String taskIdentifier = '$taskId-$sanitizedTitle';
    try {
      // 1. Setup paths
      final tempDir = await PathService.getTaskTempPath(taskIdentifier);
      final absoluteSaveDir =
          await PathService.getAbsoluteSavePath(AppConfig.instance.saveDir);
      final finalSavePath = path.join(absoluteSaveDir, '$sanitizedTitle.mp4');

      logger.i(
          'Task $taskId starting. Temp dir: $tempDir, Save path: $finalSavePath');

      // 2. Parse M3U8
      final segmentUrls = await _parseM3u8(m3u8Url);
      if (segmentUrls.isEmpty) {
        throw Exception('No segments found in M3U8 file.');
      }
      logger.i('Task $taskId found ${segmentUrls.length} segments.');

      // 3. Download segments
      final downloadedSegments = await _downloadSegments(
          taskId, tempDir, segmentUrls, totalSizeInBytes);

      // 4. Check if download was cancelled
      if (_cancellationTokens[taskId] == true) {
        logger.i(
            'Task $taskId was cancelled during segment download. Partial files saved.');
        _cancellationTokens.remove(taskId);
        return;
      }

      // 5. Merge segments
      logger.i( 'Task $taskId finished downloading, now merging ${downloadedSegments.length} files...');
      await _mergeSegments(taskId, downloadedSegments, finalSavePath);

      // 6. Cleanup
      logger.i('Task $taskId merge complete. Cleaning up temp files...');
      await Directory(tempDir).delete(recursive: true);
      _cancellationTokens.remove(taskId);

      _progressController.add(DownloadProgressUpdate(
          taskId: taskId,
          progress: 1.0,
          bitSpeedPerSecond: 0,
          downloadedBytes: totalSizeInBytes,
          totalBytes: totalSizeInBytes,
          status: DownloadStatus.completed));
    } catch (e, s) {
      logger.e('Error during download for task $taskId',
          error: e, stackTrace: s);
      _cancellationTokens.remove(taskId);
      _progressController.add(DownloadProgressUpdate(
          taskId: taskId,
          progress: 0.0,
          bitSpeedPerSecond: 0,
          downloadedBytes: 0,
          status: DownloadStatus.failed,
          totalBytes: totalSizeInBytes));
      rethrow;
    }
  }

  Future<List<String>> _parseM3u8(String m3u8Url) async {
    final m3u8Uri = Uri.parse(m3u8Url);
    final response = await http.get(m3u8Uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to download M3U8 file: ${response.statusCode}');
    }

    final lines = response.body.split('\n');
    final segmentUrls = <String>[];
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('#')) {
        segmentUrls.add(m3u8Uri.resolve(trimmedLine).toString());
      }
    }
    return segmentUrls;
  }

  Future<List<String>> _downloadSegments(int taskId, String tempDir,
      List<String> segmentUrls, int totalSize) async {
    const int maxConcurrentDownloads = 8;
    final List<String> downloadedSegmentPaths = [];
    final List<String> segmentsToDownload = [];
    final Map<String, String> urlToPathMap = {};
    int totalCount = segmentUrls.length;
    int downloadedCount = 0;

    for (int i = 0; i < totalCount; i++) {
      final segmentFileName = '${i.toString().padLeft(8, '0')}.ts';
      final segmentPath = path.join(tempDir, segmentFileName);
      final segmentUrl = segmentUrls[i];

      downloadedSegmentPaths.add(segmentPath);
      final segmentFile = File(segmentPath);
      if (await segmentFile.exists()) {
        downloadedCount++;
      } else {
        segmentsToDownload.add(segmentUrl);
        urlToPathMap[segmentUrl] = segmentPath;
      }
    }

    if (downloadedCount > 0) {
      final progress = (totalCount > 0) ? (downloadedCount / totalCount) : 0.0;
      _progressController.add(DownloadProgressUpdate(
          taskId: taskId,
          progress: progress,
          bitSpeedPerSecond: 0,
          downloadedBytes: (progress * totalSize).toInt(),
          totalBytes: totalSize,
          status: DownloadStatus.downloading));
    }

    if (segmentsToDownload.isEmpty) {
      downloadedSegmentPaths.sort();
      return downloadedSegmentPaths;
    }
    logger.i(
        'Task $taskId: $downloadedCount segments exist, ${segmentsToDownload.length} to download.');

    final client = http.Client();
    final urlStream = Stream.fromIterable(segmentsToDownload);

    Future<void> downloadWorker(String url) async {
      if (_cancellationTokens[taskId] == true) return;
      try {
        final response = await client.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await File(urlToPathMap[url]!).writeAsBytes(response.bodyBytes);
          
          // 使用同步方式更新进度，避免并发问题
          downloadedCount++;
          final progress =
              (totalCount > 0) ? (downloadedCount / totalCount) : 0.0;
          _progressController.add(DownloadProgressUpdate(
              taskId: taskId,
              progress: progress,
              bitSpeedPerSecond: 0, // Speed calculation can be added here
              downloadedBytes: (progress * totalSize).toInt(),
              totalBytes: totalSize,
              status: DownloadStatus.downloading));
        } else {
          logger.e('Failed segment: $url (status: ${response.statusCode})');
        }
      } catch (e, s) {
        logger.e('Error downloading segment $url', error: e, stackTrace: s);
      }
    }

    final pool = Stream.fromFutures(
      List.generate(
        maxConcurrentDownloads,
        (_) => Future(() async {
          await for (final url in urlStream) {
            if (_cancellationTokens[taskId] == true) break;
            await downloadWorker(url);
          }
        }),
      ),
    );

    await pool.toList();

    client.close();
    downloadedSegmentPaths.sort();
    return downloadedSegmentPaths;
  }

  Future<void> _mergeSegments(
      int taskId, List<String> segmentPaths, String finalSavePath) async {
    final fileListContent =
        segmentPaths.map((p) => "file '${p.replaceAll('\\', '/')}'").join('\n');
    final tempDir = path.dirname(segmentPaths.first);
    final fileListPath = path.join(tempDir, 'filelist.txt');
    await File(fileListPath).writeAsString(fileListContent);

    final String exeDir = path.dirname(Platform.resolvedExecutable);
    final String ffmpegPath = path.join(
        exeDir, 'data', 'flutter_assets', 'assets', 'ffmpeg', 'ffmpeg.exe');
    if (!await File(ffmpegPath).exists()) {
      throw Exception('打包的 ffmpeg.exe 未找到，路径: $ffmpegPath');
    }

    final process = await Process.start(
      ffmpegPath,
      [
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        fileListPath,
        '-c',
        'copy',
        finalSavePath,
      ],
    );

    _activeMergeProcesses[taskId] = process;
    final stdErr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    _activeMergeProcesses.remove(taskId);

    if (exitCode != 0) {
      throw Exception('FFMPEG merge failed with exit code $exitCode.\n$stdErr');
    }
  }

  void stopDownload(int taskId) {
    if (_cancellationTokens.containsKey(taskId)) {
      logger.i('Sending cancellation signal to task $taskId.');
      _cancellationTokens[taskId] = true;
    }
    if (_activeMergeProcesses.containsKey(taskId)) {
      logger.i('Stopping merge process for task $taskId.');
      _activeMergeProcesses[taskId]?.kill();
      _activeMergeProcesses.remove(taskId);
    }
  }

  void stopAllDownloads() {
    logger.i('Stopping all active downloads...');
    for (var taskId in _cancellationTokens.keys) {
      _cancellationTokens[taskId] = true;
    }
    for (final process in _activeMergeProcesses.values) {
      process.kill();
    }
    _activeMergeProcesses.clear();
    logger.i('All active downloads have been sent the kill/cancellation signal.');
  }

  Future<void> mergePartialDownload(
      int taskId, String title, int totalSizeInBytes) async {
    logger.i('Starting partial merge for task $taskId.');
    final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String taskIdentifier = '$taskId-$sanitizedTitle';
    final tempDir = await PathService.getTaskTempPath(taskIdentifier);

    final segmentFiles = (await Directory(tempDir).list().toList())
        .where((f) => f.path.endsWith('.ts'))
        .map((f) => f.path)
        .toList()
      ..sort();

    if (segmentFiles.isEmpty) {
      logger.w('No segments found to merge for task $taskId.');
      return;
    }

    final absoluteSaveDir =
        await PathService.getAbsoluteSavePath(AppConfig.instance.saveDir);
    final finalSavePath =
        path.join(absoluteSaveDir, '${sanitizedTitle}_partial.mp4');

    try {
      await _mergeSegments(taskId, segmentFiles, finalSavePath);
      logger.i(
          'Partial merge for task $taskId complete. Cleaning up temp files...');
      await Directory(tempDir).delete(recursive: true);
      _cancellationTokens.remove(taskId);
    } catch (e, s) {
      logger.e('Error during partial merge for task $taskId',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  void dispose() {
    _progressController.close();
    logger.i('Disposing download manager');
    stopAllDownloads();
  }
} 