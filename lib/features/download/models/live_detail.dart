import 'package:live_down/core/configs/local_setting.dart';
import 'package:live_down/core/services/path_service.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:path/path.dart' as p;

class LiveDetail {
  String replayUrl;
  String coverUrl;
  String title;
  String liveId;
  int totalSize; //byte
  int duration; //second
  DownloadFileType fileType;
  VideoPlatform platform;

  LiveDetail(
      {this.replayUrl = '',
      this.coverUrl = '',
      this.title = '',
      this.liveId = '',
      this.fileType = DownloadFileType.unknown,
      this.platform = VideoPlatform.unknown,
      this.totalSize = 0,
      this.duration = 0});

  int get size => totalSize;
  set size(int value) => totalSize = value;

  Future<ViewDownloadInfo> toViewDownloadInfo() async {
    final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String taskIdentifier = '$liveId-$sanitizedTitle';
    final tempDir = await PathService.getTaskTempPath(taskIdentifier);
    final absoluteSaveDir = await PathService.getAbsoluteSavePath(LocalSetting.instance.saveDir);
    final finalSavePath = p.join(absoluteSaveDir, '$sanitizedTitle.mp4');
    return ViewDownloadInfo(
      id: liveId,
      downloadUrl: replayUrl,
      coverUrl: coverUrl,
      title: title,
      platform: platform,
      fileType: fileType,
      totalSize: totalSize,
      duration: duration,
      segementPath: tempDir,
      finalSavePath: finalSavePath,
    );
  }
}



class DownloadError implements Exception {
  final String message;
  DownloadError(this.message);

  @override
  String toString() => 'DownloadError: $message';
} 