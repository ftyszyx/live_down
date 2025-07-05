import 'dart:io';

enum DownloadStatus { idle, downloading, paused,  failed, merging ,completed}
enum DownloadFileType { m3u8, mp4, unknown }
enum VideoPlatform {
  kuaishou('快手'),
  taobao('淘宝'),
  unknown('未知');
  final String title;
  const VideoPlatform(this.title);
}

/// 下载进度更新
class DownloadProgressUpdate {
  final String id;
  final int bitSpeedPerSecond;
  final int progressCurrent;
  final int progressTotal;
  final DownloadStatus status;

  DownloadProgressUpdate({
    required this.id,
    required this.bitSpeedPerSecond,
    required this.progressCurrent,
    required this.progressTotal,
    required this.status,
  });
}

/// 下载任务
class DownloadTask {
  String id;
  String url;
  String title;
  DownloadFileType fileType;
  DownloadStatus status;
  Process? mergeProcess;
  String tempDir;
  String finalSavePath;
  List<String> segmentUrls;
  Set<String> okSegmentPaths;
  int curIndex;//当前下载的进度
  DownloadTask({required this.id, required this.url, this.title='', this.status=DownloadStatus.idle, this.tempDir="", this.fileType=DownloadFileType.unknown,
  this.finalSavePath='', List<String>? segmentUrls, Set<String>? segmentPaths, this.curIndex=0})
    : segmentUrls = segmentUrls ?? [],
      okSegmentPaths = segmentPaths ?? {};
}

/// 下载任务信息
class ViewDownloadInfo {
  String id;
  VideoPlatform platform;
  DownloadFileType fileType;
  String downloadUrl;
  String coverUrl;
  int totalSize;
  int duration;
  double progress;
  String title;
  final String segementPath;
  final String finalSavePath;
  bool isSelected;
  int bitSpeedPerSecond;
  DownloadStatus status;

  ViewDownloadInfo({
    this.fileType = DownloadFileType.m3u8,
    required this.downloadUrl,
    required this.platform,
    required this.id,
    required this.coverUrl,
    this.totalSize = 0,
    this.duration = 0,
    this.progress = 0.0,
    required this.title,
    this.isSelected = false,
    this.bitSpeedPerSecond = 0,
    this.finalSavePath='',
    this.segementPath='',
    this.status = DownloadStatus.idle,
  });

  DownloadTask toDownloadTask() {
    return DownloadTask(
      id: id,
      url: downloadUrl,
      title: title,
      status: status,
      tempDir: segementPath,
      finalSavePath: finalSavePath,
      fileType: fileType,
    );
  }



  Map<String, dynamic> toJson() {
    return {
      'platform': platform.toString(),
      'liveId': id,
      'coverUrl': coverUrl,
      'fileType': fileType.toString(),
      'downloadUrl': downloadUrl,
      'totalSize': totalSize,
      'duration': duration,
      'customName': title,
      'segementPath': segementPath,
      'finalSavePath': finalSavePath,
      'status': status.toString(),
    };
  }

  static ViewDownloadInfo fromJson(Map<String, dynamic> map) {
    return ViewDownloadInfo(
      platform: VideoPlatform.values .firstWhere((e) => e.toString() == map['platform'],orElse: ()=>VideoPlatform.unknown),
      id: map['liveId'],
      coverUrl: map['coverUrl'],
      fileType: DownloadFileType.values
          .firstWhere((e) => e.toString() == map['fileType']),
      downloadUrl: map['downloadUrl'],
      totalSize: map['totalSize'],
      duration: map['duration'],
      title: map['customName'],
      segementPath: map['segementPath'],
      finalSavePath: map['finalSavePath'],
      status: DownloadStatus.values
          .firstWhere((e) => e.toString() == map['status']),
    );
  }
} 