import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:puppeteer/puppeteer.dart';
import 'logger.dart';

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

class UrlParseService {
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

  static Future<LiveDetail> _parseFromTaobao(String shareText) async {
    // 2. 提取短链接
    final shortUrl = _extractShortUrl(shareText);
    if (shortUrl == null) {
      throw DownloadError('在分享文本中找不到有效的淘宝短链接');
    }

    logger.i('提取到短链接: $shortUrl');

    // 3. 获取长链接
    final longUrl = await _getRedirectUrl(shortUrl);
    if (longUrl == null) {
      throw DownloadError('无法获取跳转后的长链接');
    }
    logger.i('获取到长链接: $longUrl');

    // 4. 提取 feed_id
    final feedId = _extractFeedId(longUrl);
    if (feedId == null) {
      throw DownloadError('在链接中找不到 feed_id');
    }
    logger.i('提取到 feed_id: $feedId');

    // 5. 获取直播详情
    final liveDetail = await _getLiveDetail(feedId);
    if (liveDetail.replayUrl == null || liveDetail.replayUrl!.isEmpty) {
      throw DownloadError('获取到直播详情，但找不到回放链接 (replayUrl)');
    }
    logger.i('获取到 m3u8 链接: ${liveDetail.replayUrl}');
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
      logger.i('正在启动本地浏览器以解析链接 ...');

      final String exeDir = path.dirname(Platform.resolvedExecutable);
      final String chromiumPath = path.join( exeDir, 'data', 'flutter_assets', 'assets', 'chrome-win', 'chrome.exe');
      if (!await File(chromiumPath).exists()) {
        throw DownloadError('打包的 chrome.exe 未找到，路径: $chromiumPath');
      }
      browser = await puppeteer.launch(executablePath: chromiumPath, headless: false);

      final page = await browser.newPage();

      await page.setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1');

      logger.i('浏览器正在导航到: $shortUrl');
      await page.goto(shortUrl, wait: Until.networkIdle);

      final finalUrl = page.url;
      logger.i('浏览器解析完成，最终链接: $finalUrl');

      return finalUrl;
    } catch (e) {
      logger.e('使用浏览器解析链接失败', error: e);
      return null;
    } finally {
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
      logger.e('获取直播详情时出错', error: e);
      throw DownloadError('获取直播详情失败: $e');
    }
  }
}
