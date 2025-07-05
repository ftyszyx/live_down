import 'dart:io';

import 'package:live_down/core/configs/app_cookie.dart';
import 'package:live_down/features/download/models/live_detail.dart';
import 'package:path/path.dart' as path;
import 'package:puppeteer/puppeteer.dart';
import 'package:live_down/core/services/logger_service.dart';

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

  static String formatDownloadSpeed(int speedBytesPerSecond) {
    if (speedBytesPerSecond < 1024) {
      return '${speedBytesPerSecond}B/s';
    }
    if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    }
    if (speedBytesPerSecond < 1024 * 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
    return '${(speedBytesPerSecond / 1024 / 1024 / 1024).toStringAsFixed(2)} GB/s';
  }

  static void openPath(String path) {
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  static Future<(Browser, Page)> runBrowser({required String url, required String keyname,Function(Request)? onRequest,Function(Response)? onResponse}) async {
    try {
      final String exeDir = path.dirname(Platform.resolvedExecutable);
      final String chromiumPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'chrome-win', 'chrome.exe');
      if (!await File(chromiumPath).exists()) {
        throw DownloadError('打包的 chrome.exe 未找到，路径: $chromiumPath');
      }
      logger.i('chromiumPath: $chromiumPath');
      var browser = await puppeteer.launch(
        executablePath: chromiumPath,
        headless: false,
        ignoreHttpsErrors: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          // '--auto-open-devtools-for-tabs',
          '--disable-dev-shm-usage',
        ],
      );
      final page = await browser.newPage();
      page.onRequest.listen((request) {
        if(onRequest!=null){
          onRequest(request);
        }
      });
      page.onResponse.listen((response) {
        if(onResponse!=null){
          onResponse(response);
        }
      });
      await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1');
      logger.i('浏览器正在导航到: $url');
      await page.goto(url, wait: Until.networkIdle);
      //set cookies
      final cookies = await AppCookie.getCookies(keyname);
      await page.setCookies(cookies.map((e) => CookieParam(name: e.name, value: e.value, domain: e.domain, path: e.path)).toList());
      return (browser, page);
    } catch (e) {
      logger.e('启动浏览器失败', error: e);
      throw DownloadError('启动浏览器失败');
    }
  }

  static Future<void> playMp4(String videoPath) async {
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final ffplayPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'ffmpeg', 'ffplay.exe');
    if (!await File(ffplayPath).exists()) {
      throw DownloadError('打包的 ffplay.exe 未找到，路径: $ffplayPath');
    }
    final result = await Process.run(ffplayPath, [videoPath]);
    if (result.exitCode == 0) {
      return;
    }
    throw DownloadError('播放失败');
  }

}

