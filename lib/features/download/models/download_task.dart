enum DownloadStatus { idle, downloading, paused, completed, failed, merging }
enum DownloadFileType { m3u8, mp4 }

class DownloadTask {
  final int id;
  DownloadFileType fileType;
  String downloadUrl;
  int totalSize;
  int duration;
  double progress;
  final String customName;
  bool isSelected;
  int bitSpeedPerSecond;
  DownloadStatus status;
  String speed = '';

  DownloadTask({
    required this.id,
    this.fileType = DownloadFileType.m3u8,
    required this.downloadUrl,
    this.totalSize = 0,
    this.duration = 0,
    this.progress = 0.0,
    required this.customName,
    this.isSelected = false,
    this.bitSpeedPerSecond = 0,
    this.status = DownloadStatus.idle,
  });
} 