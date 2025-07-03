class LiveDetail {
  String replayUrl;
  String title;
  int liveId;
  int totalSize; //byte
  int duration; //second

  LiveDetail(
      {this.replayUrl = '',
      this.title = '',
      this.liveId = 0,
      this.totalSize = 0,
      this.duration = 0});

  int get size => totalSize;
  set size(int value) => totalSize = value;
}

class DownloadError implements Exception {
  final String message;
  DownloadError(this.message);

  @override
  String toString() => 'DownloadError: $message';
} 