import 'package:live_down/features/download/services/download_manager_service.dart';
import 'models/download_task.dart';
import 'models/live_detail.dart';
import 'package:live_down/features/download/services/url_parse_service.dart';
// 下载管理器
class DownloadRepository {
  final DownloadManagerService _downloadManager;

  DownloadRepository({
    required DownloadManagerService downloadManager,
  }) : _downloadManager = downloadManager;

  Stream<DownloadProgressUpdate> get progressStream =>
      _downloadManager.progressStream;

  Future<LiveDetail> parseUrl(String url) {
    return UrlParseService.parseUrl(url);
  }

  Future<void> startDownload(ViewDownloadInfo task) {
    return _downloadManager.startDownloadTask(task);
  }

  void stopDownload(String taskId) {
    _downloadManager.stopDownload(taskId);
  }

  void stopAllDownloads() {
    _downloadManager.stopAllDownloads();
  }

  Future<void> mergePartialDownload(ViewDownloadInfo task) {
    return _downloadManager.mergeSegmentsPartial(task.id);
  }

  void dispose() {
    _downloadManager.dispose();
  }
} 