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

class DownloadTask {
  int id;
  String m3u8Url;
  String title;
  DownloadStatus status;
  Process? mergeProcess;
  String tempDir;
  String finalSavePath;
  List<String> segmentUrls;
  Set<String> okSegmentPaths;
  int curIndex;//当前下载的进度
  DownloadTask({required this.id, required this.m3u8Url, this.title='', this.status=DownloadStatus.idle, this.tempDir="", 
  this.finalSavePath='', List<String>? segmentUrls, Set<String>? segmentPaths, this.curIndex=0})
    : segmentUrls = segmentUrls ?? [],
      okSegmentPaths = segmentPaths ?? {};
}

class DownloadManagerService {
  static final DownloadManagerService _instance = DownloadManagerService._internal();
  factory DownloadManagerService() => _instance;
  DownloadManagerService._internal();
  final Map<int, DownloadTask> _downloadTasks = {};
  // 下载进度通知 
  final _progressController = StreamController<DownloadProgressUpdate>.broadcast();
  Stream<DownloadProgressUpdate> get progressStream => _progressController.stream;

  Future<void> startDownloadTask(int taskId, String m3u8Url, String title) async {
    late DownloadTask task;
    if (_downloadTasks.containsKey(taskId)) {
      task = _downloadTasks[taskId]!;
      var status = task.status;
      if (status == DownloadStatus.downloading) {
        logger.w('Task $taskId is already running.');
        return;
      }
      if (status == DownloadStatus.completed || status == DownloadStatus.merging) {
        logger.w('Task $taskId is already completed.');
        return;
      }
    } else {
      task = DownloadTask(
        id: taskId,
        m3u8Url: m3u8Url,
        title: title,
        status: DownloadStatus.downloading,
      );
      _downloadTasks[taskId] = task;
      final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final String taskIdentifier = '$taskId-$sanitizedTitle';
      final tempDir = await PathService.getTaskTempPath(taskIdentifier);
      final absoluteSaveDir = await PathService.getAbsoluteSavePath(AppConfig.instance.saveDir);
      final finalSavePath = path.join(absoluteSaveDir, '$sanitizedTitle.mp4');
      task.tempDir = tempDir;
      task.finalSavePath = finalSavePath;
      logger.i('Task $taskId starting. Temp dir: $tempDir, Save path: $finalSavePath');
    }
    if (task.segmentUrls.isEmpty) {
      final segmentUrls = await _parseM3u8(m3u8Url);
      if (segmentUrls.isEmpty) {
        throw Exception('No segments found in M3U8 file.');
      }
      task.segmentUrls = segmentUrls;
    }
    task.status = DownloadStatus.downloading;
    // 3. Download segments
    await _downloadSegments(task);
    if(task.okSegmentPaths.length != task.segmentUrls.length){
      task.status = DownloadStatus.failed;
      logger.e('Download segments failed for task $taskId.');
      return;
    }
    await _mergeSegments(task);
    task.status = DownloadStatus.completed;
    _downloadTasks.remove(taskId);
    _progressController.add(DownloadProgressUpdate(
        taskId: taskId,
        bitSpeedPerSecond: 0,
        progressCurrent: task.segmentUrls.length,
        progressTotal: task.segmentUrls.length,
        status: DownloadStatus.completed));
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

  Future<void> _downloadSegments(DownloadTask task) async {
    const int maxConcurrentDownloads = 8;
    int totalCount = task.segmentUrls.length;
    final client = http.Client();
    var workers = <Future<void>>[];
    int totalBytesDownloaded = 0;
    final stopwatch = Stopwatch()..start();
    void reportProgress() {
      if (!_progressController.isClosed) {
      var bitSpeed = 0;
      if(stopwatch.elapsed.inSeconds > 0){
        bitSpeed = (totalBytesDownloaded * 8) ~/ stopwatch.elapsed.inSeconds;
      }
        _progressController.add(DownloadProgressUpdate(
            taskId: task.id,
            bitSpeedPerSecond: bitSpeed,
            progressCurrent: task.curIndex+1,
            progressTotal: totalCount,
            status: DownloadStatus.downloading));
      }
    }

    Future downloadWorker() async {
      if (task.status != DownloadStatus.downloading) return;
      while (task.curIndex < totalCount) {
        bool okflag = false;
        int retryCount = 0;
        int curIndex = task.curIndex;
        task.curIndex++;
        final segmentFileName = '${curIndex.toString().padLeft(8, '0')}.ts';
        final segmentPath = path.join(task.tempDir, segmentFileName);
        try {
          if(task.okSegmentPaths.contains(segmentPath)){
            reportProgress();
            continue;
          }
          final segmentUrl = task.segmentUrls[curIndex];
          final segmentFile = File(segmentPath);
          if (!await segmentFile.exists()) {
            final response = await client.get(Uri.parse(segmentUrl));
            if (response.statusCode == 200) {
              okflag = true;
              final bytes = response.bodyBytes;
              try{
                await File(segmentPath).writeAsBytes(bytes);
              } catch (e, s) {
                logger.e('Failed to write segment ${task.segmentUrls[curIndex]}', error: e, stackTrace: s);
                File(segmentPath).deleteSync();
                return;
              }
              task.okSegmentPaths.add(segmentPath);
              totalBytesDownloaded += bytes.length;
            } else {
              if(retryCount>=3){
                logger.e('Failed to download segment ${task.segmentUrls[curIndex]}', error: response.statusCode);
                return;
              }
              else{
              retryCount++;
              await Future.delayed(const Duration(seconds: 1));
              continue;
              }
            }
          } else {
            okflag = true;
            task.okSegmentPaths.add(segmentPath);
          }
        } catch (e, s) {
          if(retryCount>=3){
            logger.e('Failed to download segment ${task.segmentUrls[curIndex]}', error: e, stackTrace: s);
            return;
          }
          else{
            retryCount++;
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        } finally {
          if (okflag) {
            reportProgress();
          }
        }
      }
    }

    for (int i = 0; i < maxConcurrentDownloads; i++) {
      workers.add(downloadWorker());
    }
    await Future.wait(workers);
    client.close();
    stopwatch.stop();
  }

  Future<void> _mergeSegments(DownloadTask task) async {
    var taskOkSegmentPaths = task.okSegmentPaths.toList();
    task.status = DownloadStatus.merging;
    taskOkSegmentPaths.sort((a, b) => a.compareTo(b));
    final fileListContent = taskOkSegmentPaths.map((p) => "file '${p.replaceAll('\\', '/')}'").join('\n');
    final fileListPath = path.join(task.tempDir, 'filelist.txt');
    await File(fileListPath).writeAsString(fileListContent);

    final String exeDir = path.dirname(Platform.resolvedExecutable);
    final String ffmpegPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'ffmpeg', 'ffmpeg.exe');
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
        task.finalSavePath,
      ],
    );

    task.mergeProcess = process;
    final stdErr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    task.mergeProcess = null;
    if (exitCode != 0) {
      throw Exception('FFMPEG merge failed with exit code $exitCode.\n$stdErr');
    }
    task.okSegmentPaths.clear();
    File(task.tempDir).deleteSync(recursive: true);
    logger.i('Merge segments for task $task.id complete. Cleaning up temp files...');
  }

  void stopDownload(int taskId) {
    if (_downloadTasks.containsKey(taskId)) {
      _downloadTasks[taskId]!.status = DownloadStatus.paused;
      logger.i('Sending cancellation signal to task $taskId.');
      logger.i('Stopping merge process for task $taskId.');
      _downloadTasks[taskId]?.mergeProcess?.kill();
      _downloadTasks[taskId]?.mergeProcess = null;
    }
  }

  void stopAllDownloads() {
    logger.i('Stopping all active downloads...');
    for (var task in _downloadTasks.values) {
      task.status = DownloadStatus.paused;
      stopDownload(task.id);
    }
    logger.i('All active downloads have been sent the kill/cancellation signal.');
  }

  Future<void> mergeSegmentsPartial(int taskId) async {
    if(_downloadTasks.containsKey(taskId)){
      var task = _downloadTasks[taskId]!;
      await _mergeSegments(task);
    }
    else{
      throw Exception('Task $taskId not found');
    }
  }

  void dispose() {
    _progressController.close();
    logger.i('Disposing download manager');
    stopAllDownloads();
  }
}
