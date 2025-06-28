import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PathService {
  /// Converts a path from the config file into a full, absolute path.
  ///
  /// Handles special tokens like `<Downloads>` and `<Documents>`.
  /// Treats other paths as relative to the application's documents directory.
  /// If the final directory does not exist, it will be created.
  static Future<String> getAbsoluteSavePath(String configPath) async {
    Directory baseDir;

    // Handle special tokens for common directories
    if (configPath.toLowerCase() == '<downloads>') {
      // getDownloadsDirectory can be null on some platforms. Fallback to documents.
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
} 