import 'dart:async';
import 'package:flutter/material.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:live_down/features/download/download_repository.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:live_down/features/download/services/download_manager_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DownloadRepository _repository;
  StreamSubscription<DownloadProgressUpdate>? _progressSubscription;

  final List<ViewDownloadInfo> _tasks = [];
  List<ViewDownloadInfo> get tasks => _tasks;

  bool _isParsing = false;
  bool get isParsing => _isParsing;

  int _nextTaskId = 1;

  HomeViewModel({required DownloadRepository repository})
      : _repository = repository {
    _progressSubscription = _repository.progressStream.listen(_onProgressUpdate);
  }

  void _onProgressUpdate(DownloadProgressUpdate update) {
    try {
      final task = _tasks.firstWhere((t) => t.id == update.taskId);
      task.progress = update.progressCurrent / update.progressTotal;
      task.bitSpeedPerSecond = update.bitSpeedPerSecond;
      if (update.status == DownloadStatus.failed) {
        task.status = DownloadStatus.failed;
      } else if (update.status == DownloadStatus.completed) {
        task.status = DownloadStatus.completed;
      } else if (task.status != DownloadStatus.merging &&
          task.status != DownloadStatus.paused) {
        task.status = DownloadStatus.downloading;
      }
      notifyListeners();
    } catch (e) {
      // Task not found, might have been removed.
    }
  }

  Future<void> analyzeUrl(String url) async {
    if (url.isEmpty || _isParsing) return;

    _isParsing = true;
    notifyListeners();

    try {
      final liveDetail = await _repository.parseUrl(url);
      final newTask = ViewDownloadInfo(
        id: _nextTaskId++,
        downloadUrl:
            liveDetail.replayUrl.isEmpty ? '未知地址' : liveDetail.replayUrl,
        customName: liveDetail.title,
        totalSize: liveDetail.size,
        duration: liveDetail.duration,
      );
      _tasks.add(newTask);
    } catch (e, s) {
      logger.e('解析时发生未知错误', error: e, stackTrace: s);
      // Here you might want to expose an error message to the UI
    } finally {
      _isParsing = false;
      notifyListeners();
    }
  }

  void onSelectChanged(bool? isSelected, ViewDownloadInfo task) {
    task.isSelected = isSelected ?? false;
    notifyListeners();
  }

  void startSelectedDownloads() {
    final selectedTasks = _tasks.where((task) =>
        task.isSelected &&
        (task.status == DownloadStatus.idle ||
            task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.failed));

    for (final task in selectedTasks) {
      task.status = DownloadStatus.downloading;
      task.speed = '等待中...';
      _repository.startDownload(task).catchError((e, s) {
        logger.e('任务 ${task.customName} 下载失败', error: e, stackTrace: s);
        task.status = DownloadStatus.failed;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void stopSelectedDownloads() {
    final selectedTasks = _tasks.where((task) =>
        task.isSelected &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.merging));

    for (final task in selectedTasks) {
      _repository.stopDownload(task.id);
      task.status = DownloadStatus.paused;
      task.speed = '已暂停';
    }
    notifyListeners();
  }

  Future<void> mergeSelectedDownloads() async {
    final selectedTasks = _tasks
        .where((task) => task.isSelected && task.status == DownloadStatus.paused)
        .toList();

    for (final task in selectedTasks) {
      task.status = DownloadStatus.merging;
      task.speed = '合并中...';
      notifyListeners();
      try {
        await _repository.mergePartialDownload(task);
        _tasks.remove(task);
      } catch (e, s) {
        logger.e('任务 ${task.customName} 合并失败', error: e, stackTrace: s);
        task.status = DownloadStatus.failed;
        task.speed = '合并失败';
      } finally {
        notifyListeners();
      }
    }
  }

  void clearCompletedDownloads() {
    _tasks.removeWhere((task) =>
        task.status == DownloadStatus.completed ||
        task.status == DownloadStatus.failed);
    notifyListeners();
  }

  void clearCompletedTasks() {
    _tasks.removeWhere((task) =>
        task.status == DownloadStatus.completed ||
        task.status == DownloadStatus.failed);
    notifyListeners();
  }

  void stopAllDownloads() {
    _repository.stopAllDownloads();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
 