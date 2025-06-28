import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:puppeteer/puppeteer.dart';

class LiveDetail {
  final String? replayUrl;
  final String title;

  LiveDetail({this.replayUrl, required this.title});

  factory LiveDetail.fromJson(Map<String, dynamic> json) {
    return LiveDetail(
      replayUrl: json['replayUrl'],
      title: json['title'] ?? '未命名直播',
    );
  }
}

class DownloadError implements Exception {
  final String message;
  DownloadError(this.message);

  @override
  String toString() => 'DownloadError: $message';
}

class DownloaderService {
  static final Dio _dio = Dio();

  /// Parses a share text/URL to extract video details like title and m3u8 URL.
  static Future<LiveDetail> parseUrl(String shareText) async {
    // 1. 根据分享文本判断平台
    if (shareText.contains('m.tb.cn')) {
      return await _parseFromTaobao(shareText);
    } else {
      throw DownloadError('不支持的平台');
    }
  }

  /// Executes the download of an m3u8 stream using the provided URL and title.
  static Future<void> executeDownload(String m3u8Url, String title) async {
    try {
      // 1. 获取保存路径
      final downloadsPath = await _getDownloadsPath();
      if (downloadsPath == null) {
        throw DownloadError('无法获取下载目录');
      }
      final sanitizedTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = path.join(downloadsPath, '$sanitizedTitle.mp4');
      log('将保存到: $savePath');

      // 2. 获取打包的 ffmpeg.exe 路径
      final String exeDir = path.dirname(Platform.resolvedExecutable);
      final String ffmpegPath = path.join(
          exeDir, 'data', 'flutter_assets', 'assets', 'ffmpeg', 'ffmpeg.exe');

      if (!await File(ffmpegPath).exists()) {
        throw DownloadError('打包的 ffmpeg.exe 未找到，路径: $ffmpegPath');
      }

      // 3. 执行 ffmpeg 命令
      log('开始使用 ffmpeg 下载...');
      final result = await Process.run(
        ffmpegPath,
        [
          '-protocol_whitelist',
          'file,http,https,tcp,tls,crypto', // 安全起见，声明允许的协议
          '-i',
          m3u8Url,
          '-c',
          'copy', // 直接复制流，不重新编码，速度最快
          '-bsf:a',
          'aac_adtstoasc', // 转换音频流格式，提高兼容性
          savePath,
        ],
      );

      if (result.exitCode == 0) {
        log('ffmpeg 下载成功: $savePath');
      } else {
        log('ffmpeg 执行失败.');
        log('FFmpeg Stderr: ${result.stderr}');
        log('FFmpeg Stdout: ${result.stdout}');
        throw DownloadError('ffmpeg 执行失败，退出代码: ${result.exitCode}');
      }
    } catch (e) {
      log('下载 M3U8 视频失败: $e');
      throw DownloadError('下载 M3U8 视频失败: $e');
    }
  }

  static Future<LiveDetail> _parseFromTaobao(String shareText) async {
    // 2. 提取短链接
    final shortUrl = _extractShortUrl(shareText);
    if (shortUrl == null) {
      throw DownloadError('在分享文本中找不到有效的淘宝短链接');
    }

    log('提取到短链接: $shortUrl');

    // 3. 获取长链接
    final longUrl = await _getRedirectUrl(shortUrl);
    if (longUrl == null) {
      throw DownloadError('无法获取跳转后的长链接');
    }
    log('获取到长链接: $longUrl');

    // 4. 提取 feed_id
    final feedId = _extractFeedId(longUrl);
    if (feedId == null) {
      throw DownloadError('在链接中找不到 feed_id');
    }
    log('提取到 feed_id: $feedId');

    // 5. 获取直播详情
    final liveDetail = await _getLiveDetail(feedId);
    if (liveDetail.replayUrl == null || liveDetail.replayUrl!.isEmpty) {
      throw DownloadError('获取到直播详情，但找不到回放链接 (replayUrl)');
    }
    log('获取到 m3u8 链接: ${liveDetail.replayUrl}');
    return liveDetail;
  }

  static String? _extractShortUrl(String text) {
    final regex = RegExp(r'https?://m\.tb\.cn/h\.[a-zA-Z0-9]+');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  static Future<String?> _getRedirectUrl(String shortUrl) async {
    Browser? browser;
    try {
      log('正在启动本地浏览器以解析链接 d...');

      // 1. 定义我们打包的 chromium.exe 的路径
      final String exeDir = path.dirname(Platform.resolvedExecutable);
      final String chromiumPath = path.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'chromium',
        'chrome.exe',
      );

      // 2. 检查这个文件是否存在gg
      if (!await File(chromiumPath).exists()) {
        throw DownloadError('打包的 chrome.exe 未找到，路径: $chromiumPath');
      }

      // 3. 启动 puppeteer，并明确指定可执行文件路径
      browser = await puppeteer.launch(
        executablePath: chromiumPath,
        headless: true, // 在后台运行
        args: ['--no-sandbox', '--disable-setuid-sandbox'], // 推荐的参数
      );

      final page = await browser.newPage();

      // 设置一个真实的用户代理
      await page.setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1');

      log('浏览器正在导航到: $shortUrl');
      // 等待页面网络空闲，确保所有 JS 都已执行
      await page.goto(shortUrl, wait: Until.networkIdle);

      // 获取执行和跳转后的最终 URL
      final finalUrl = page.url;
      log('浏览器解析完成，最终链接: $finalUrl');

      return finalUrl;
    } catch (e) {
      log('使用浏览器解析链接失败: $e');
      return null;
    } finally {
      // 确保浏览器被关闭
      await browser?.close();
    }
  }

  static String? _extractFeedId(String longUrl) {
    final uri = Uri.parse(longUrl);
    String? feedId = uri.queryParameters['feed_id'];
    if (feedId != null && feedId.isNotEmpty) {
      return feedId;
    }
    return uri.queryParameters['id'];
  }

  static Future<LiveDetail> _getLiveDetail(String feedId) async {
    final apiUrl =
        'https://alive-interact.alicdn.com/livedetail/common/$feedId';
    try {
      final response = await _dio.get(apiUrl);
      if (response.statusCode == 200 && response.data != null) {
        // The response body is a string that looks like a JSONP callback.
        // We need to extract the JSON part from it.
        String responseBody = response.data.toString();

        // Find the first '{' and the last '}'
        int startIndex = responseBody.indexOf('{');
        int endIndex = responseBody.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          String jsonString = responseBody.substring(startIndex, endIndex + 1);
          final jsonData = jsonDecode(jsonString);
          return LiveDetail.fromJson(jsonData);
        } else {
          throw DownloadError('无法从响应中解析出有效的 JSON 数据');
        }
      } else {
        throw DownloadError('获取直播详情失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      log('获取直播详情时出错: $e');
      throw DownloadError('获取直播详情失败: $e');
    }
  }

  static Future<String?> _getDownloadsPath() async {
    try {
      // For Windows, getDownloadsDirectory is the one.
      final directory = await getDownloadsDirectory();
      return directory?.path;
    } catch (e) {
      log('获取下载路径失败: $e');
      return null;
    }
  }
}
