class CommonUtils {
  static String formatSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    }
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
    }
    if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(sizeInBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  static String formatDuration(int durationInSeconds) {
    if (durationInSeconds < 60) {
      return '$durationInSeconds 秒';
    }
    if (durationInSeconds < 60 * 60) {
      return '${(durationInSeconds / 60).toStringAsFixed(2)} 分';
    }
    return '${(durationInSeconds / 60 / 60).toStringAsFixed(2)} 小时';
  }


  static  String formatDownloadSpeed(int speedBytesPerSecond){
    if(speedBytesPerSecond < 1024){
      return '${speedBytesPerSecond}B/s';
    }
    if(speedBytesPerSecond < 1024 * 1024){
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    }
    if(speedBytesPerSecond < 1024 * 1024 * 1024){
      return '${(speedBytesPerSecond / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
    return '${(speedBytesPerSecond / 1024 / 1024 / 1024).toStringAsFixed(2)} GB/s';
  }
}