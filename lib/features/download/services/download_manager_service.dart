import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:path/path.dart' as path;

class DownloadManagerService {
  static final DownloadManagerService _instance = DownloadManagerService._internal();
  factory DownloadManagerService() => _instance;
  DownloadManagerService._internal();
  final Map<String, DownloadTask> _downloadTasks = {};
  // 下载进度通知
  final _progressController = StreamController<DownloadProgressUpdate>.broadcast();
  Stream<DownloadProgressUpdate> get progressStream => _progressController.stream;

  Future<void> startDownloadTask(ViewDownloadInfo taskinfo) async {
    late DownloadTask task;
    if (_downloadTasks.containsKey(taskinfo.id)) {
      task = _downloadTasks[taskinfo.id]!;
      var status = task.status;
      if (status == DownloadStatus.downloading) {
        logger.w('Task ${taskinfo.id} is already running.');
        return;
      }
      if (status == DownloadStatus.completed || status == DownloadStatus.merging) {
        logger.w('Task ${taskinfo.id} is already completed.');
        return;
      }
    } else {
      task = taskinfo.toDownloadTask();
      _downloadTasks[taskinfo.id] = task;
      logger.i('Task ${taskinfo.id} starting. Temp dir: ${task.tempDir}, Save path: ${task.finalSavePath}');
    }
    if (taskinfo.fileType == DownloadFileType.mp4) {
      await _downloadMp4(task);
    } else {
      await _downloadM3u8(task);
    }
  }

  Future<void> _downloadMp4(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    //download file from url  mp4
    final response = await http.get(Uri.parse(task.url));
    int totalSize = 0;
    if (response.statusCode == 200) {
      //get file size
      final fileSize = response.headers['content-length'];
      if (fileSize != null) {
        totalSize = int.parse(fileSize);
      }
      await File(task.finalSavePath).writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download file from ${task.url}');
    }
    task.status = DownloadStatus.completed;
    _downloadTasks.remove(task.id);
    _progressController
        .add(DownloadProgressUpdate(id: task.id, bitSpeedPerSecond: 0, progressCurrent: totalSize, progressTotal: totalSize, status: DownloadStatus.completed));
  }

  Future<void> _downloadM3u8(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    if (task.segmentUrls.isEmpty) {
      final segmentUrls = await _parseM3u8(task.url);
      if (segmentUrls.isEmpty) {
        throw Exception('No segments found in M3U8 file.');
      }
      task.segmentUrls = segmentUrls;
    }
    await _downloadSegments(task);
    if (task.okSegmentPaths.length != task.segmentUrls.length) {
      task.status = DownloadStatus.failed;
      logger.e('Download segments failed for task ${task.id}.');
      return;
    }
    await _mergeSegments(task);
    task.status = DownloadStatus.completed;
    _downloadTasks.remove(task.id);
    _progressController
        .add(DownloadProgressUpdate(id: task.id, bitSpeedPerSecond: 0, progressCurrent: task.segmentUrls.length, progressTotal: task.segmentUrls.length, status: DownloadStatus.completed));
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
        if (stopwatch.elapsed.inSeconds > 0) {
          bitSpeed = (totalBytesDownloaded * 8) ~/ stopwatch.elapsed.inSeconds;
        }
        _progressController.add(DownloadProgressUpdate(id: task.id, bitSpeedPerSecond: bitSpeed, progressCurrent: task.curIndex + 1, progressTotal: totalCount, status: DownloadStatus.downloading));
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
          if (task.okSegmentPaths.contains(segmentPath)) {
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
              try {
                await File(segmentPath).writeAsBytes(bytes);
              } catch (e, s) {
                logger.e('Failed to write segment ${task.segmentUrls[curIndex]}', error: e, stackTrace: s);
                File(segmentPath).deleteSync();
                return;
              }
              logger.i('Download segment ${task.segmentUrls[curIndex]} success. Path: $segmentPath');
              task.okSegmentPaths.add(segmentPath);
              totalBytesDownloaded += bytes.length;
            } else {
              if (retryCount >= 3) {
                logger.e('Failed to download segment ${task.segmentUrls[curIndex]}', error: response.statusCode);
                return;
              } else {
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
          if (retryCount >= 3) {
            logger.e('Failed to download segment ${task.segmentUrls[curIndex]}', error: e, stackTrace: s);
            return;
          } else {
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
    logger.i('Merge segments for task $task.id start. Temp dir: ${task.tempDir}, Save path: ${task.finalSavePath}');
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

  void stopDownload(String taskId) {
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

  Future<void> mergeSegmentsPartial(String taskId) async {
    if (_downloadTasks.containsKey(taskId)) {
      var task = _downloadTasks[taskId]!;
      if (task.fileType == DownloadFileType.mp4) {
        for (var file in Directory(task.tempDir).listSync()) {
          if (file is File) {
            await file.copy(task.finalSavePath);
            break;
          }
        }
      } else {
        await _mergeSegments(task);
      }
    } else {
      throw Exception('Task $taskId not found');
    }
  }

  void dispose() {
    _progressController.close();
    logger.i('Disposing download manager');
    stopAllDownloads();
  }
}
