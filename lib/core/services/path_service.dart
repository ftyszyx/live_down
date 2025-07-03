import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PathService {
  static Future<String> getAbsoluteSavePath(String configPath) async {
    Directory baseDir;
    if (configPath.toLowerCase() == '<downloads>') {
      baseDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      return baseDir.path;
    }
    if (configPath.toLowerCase() == '<documents>') {
      baseDir = await getApplicationDocumentsDirectory();
      return baseDir.path;
    }
    // If the path in the config is already absolute, use it directly.
    if (p.isAbsolute(configPath)) {
      return configPath;
    }

    // Otherwise, treat it as a relative path from the user's documents directory.
    baseDir = await getApplicationDocumentsDirectory();
    final String absolutePath = p.join(baseDir.path, configPath);

    // Ensure the directory we are about to use actually exists.
    final dir = Directory(absolutePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return absolutePath;
  }

  static Future<String> getTaskTempPath(String taskIdentifier) async {
    final tempDir = await getTemporaryDirectory();
    final taskTempDir = Directory(p.join(tempDir.path, 'live_down_segs', taskIdentifier));
    if (!await taskTempDir.exists()) {
      await taskTempDir.create(recursive: true);
    }
    return taskTempDir.path;
  }
} 