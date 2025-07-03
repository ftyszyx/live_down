enum DownloadStatus { idle, downloading, paused,  failed, merging ,completed}
enum DownloadFileType { m3u8, mp4 }

class ViewDownloadInfo {
  final int id;
  DownloadFileType fileType;
  String downloadUrl;
  int totalSize;
  int duration;
  double progress;
  final String customName;
  final String segementPath;
  final String finalSavePath;
  bool isSelected;
  int bitSpeedPerSecond;
  DownloadStatus status;

  ViewDownloadInfo({
    required this.id,
    this.fileType = DownloadFileType.m3u8,
    required this.downloadUrl,
    this.totalSize = 0,
    this.duration = 0,
    this.progress = 0.0,
    required this.customName,
    this.isSelected = false,
    this.bitSpeedPerSecond = 0,
    this.finalSavePath='',
    this.segementPath='',
    this.status = DownloadStatus.idle,
  });

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'fileType': fileType.toString(),
      'downloadUrl': downloadUrl,
      'totalSize': totalSize,
      'duration': duration,
      'customName': customName,
      'segementPath': segementPath,
      'finalSavePath': finalSavePath,
      'status': status.toString(),
    };
  }

  static ViewDownloadInfo fromDbMap(Map<String, dynamic> map) {
    return ViewDownloadInfo(
      id: map['id'],
      fileType: DownloadFileType.values
          .firstWhere((e) => e.toString() == map['fileType']),
      downloadUrl: map['downloadUrl'],
      totalSize: map['totalSize'],
      duration: map['duration'],
      customName: map['customName'],
      segementPath: map['segementPath'],
      finalSavePath: map['finalSavePath'],
      status: DownloadStatus.values
          .firstWhere((e) => e.toString() == map['status']),
    );
  }
} 