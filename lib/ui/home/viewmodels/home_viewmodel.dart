import 'dart:async';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:live_down/core/configs/local_setting.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:live_down/features/download/download_repository.dart';
import 'package:live_down/core/services/logger_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DownloadRepository _repository;
  StreamSubscription<DownloadProgressUpdate>? _progressSubscription;

  final List<ViewDownloadInfo> _tasks = [];
  List<ViewDownloadInfo> get tasks => _tasks;

  bool _isParsing = false;
  bool get isParsing => _isParsing;


  HomeViewModel({required DownloadRepository repository}) : _repository = repository {
    _progressSubscription = _repository.progressStream.listen(_onProgressUpdate);
    _loadTasks();
  }

  void _loadTasks() {
    final tasks = LocalSetting.instance.tasks;
    _tasks.addAll(tasks);
    notifyListeners();
  }

  void _onProgressUpdate(DownloadProgressUpdate update) {
    try {
      final task = _tasks.firstWhere((t) => t.id == update.id);
      task.progress = update.progressCurrent / update.progressTotal;
      task.bitSpeedPerSecond = update.bitSpeedPerSecond;
      if (update.status == DownloadStatus.failed) {
        task.status = DownloadStatus.failed;
      } else if (update.status == DownloadStatus.completed) {
        task.status = DownloadStatus.completed;
        task.totalSize = update.progressTotal;
        LocalSetting.instance.updateTask(task);
      } else if (task.status != DownloadStatus.merging &&
          task.status != DownloadStatus.paused) {
        task.status = DownloadStatus.downloading;
      }
      notifyListeners();
    } catch (e) {
      // Task not found, might have been removed.
    }
  }

  Future<void> analyzeUrl(BuildContext context, String url) async {
    if (url.isEmpty || _isParsing) return;
    _isParsing = true;
    notifyListeners();
    try {
      final liveDetail = await _repository.parseUrl(url);
      final newTask = await liveDetail.toViewDownloadInfo();
      ViewDownloadInfo? oldTask = LocalSetting.instance.getTaskById(newTask.id);
      if(oldTask == null) {
        LocalSetting.instance.addTask(newTask);
      } else {
        newTask.title = oldTask.title;
      }
      _tasks.add(newTask);
    } catch (e, s) {
      logger.e('解析时发生未知错误', error: e, stackTrace: s);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
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
    final selectedTasks = tasks.where((task) =>
        task.isSelected &&
        (task.status == DownloadStatus.idle ||
            task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.failed));

    for (final task in selectedTasks) {
      task.status = DownloadStatus.downloading;
      _repository.startDownload(task).catchError((e, s) {
        logger.e('任务 ${task.title} 下载失败', error: e, stackTrace: s);
        task.status = DownloadStatus.failed;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void stopSelectedDownloads() {
    final selectedTasks = tasks.where((task) =>
        task.isSelected && (task.status == DownloadStatus.downloading || task.status == DownloadStatus.merging));
    for (final task in selectedTasks) {
      _repository.stopDownload(task.id);
      task.status = DownloadStatus.paused;
    }
    notifyListeners();
  }

  void deleteTask(ViewDownloadInfo task) {
    LocalSetting.instance.deleteTask(task.id);
    _tasks.remove(task);
    notifyListeners();
  }

  void pauseTask(ViewDownloadInfo task) {
    _repository.stopDownload(task.id);
    notifyListeners();
  }

  void startTask(ViewDownloadInfo task) {
    _repository.startDownload(task);
    notifyListeners();
  }

  void renameTask(ViewDownloadInfo task, String newName) {
    task.title = newName;
    LocalSetting.instance.updateTask(task);
    notifyListeners();
  }

  Future<void> mergeSelectedDownloads() async {
    final selectedTasks = tasks
        .where((task) => task.isSelected && task.status == DownloadStatus.paused)
        .toList();

    for (final task in selectedTasks) {
      task.status = DownloadStatus.merging;
      notifyListeners();
      try {
        await _repository.mergePartialDownload(task);
      } catch (e, s) {
        logger.e('任务 ${task.title} 合并失败', error: e, stackTrace: s);
        task.status = DownloadStatus.failed;
      } finally {
        notifyListeners();
      }
    }
  }

  void clearCompletedDownloads() {
    final completedTaskIds = tasks
        .where((task) =>
            task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.failed)
        .map((task) => task.id)
        .toList();

    for (var id in completedTaskIds) {
      LocalSetting.instance.deleteTask(id);
    }
    notifyListeners();
  }

  void clearCompletedTasks() {
    clearCompletedDownloads();
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
 