import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:puppeteer/puppeteer.dart';
import 'package:live_down/core/utils/common.dart';
import '../../../../core/services/logger_service.dart';
import '../../models/live_detail.dart';

class TaobaoParser {
  static final Dio _dio = Dio();
  static const String _keyname = 'taobao';

  static String? _extractShortUrl(String text) {
    final regex = RegExp(r'https?://m\.tb\.cn/h\.[a-zA-Z0-9]+');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  static Future<LiveDetail> parse(String shareText) async {
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
    if (liveDetail.replayUrl.isEmpty) {
      throw DownloadError('获取到直播详情，但找不到回放链接 (replayUrl)');
    }
    logger.i('获取到 m3u8 链接: ${liveDetail.replayUrl}');
    // 6. 获取 m3u8 文件总大小
    await _getM3u8TotalSize(liveDetail);
    liveDetail.platform = VideoPlatform.taobao;
    liveDetail.fileType = DownloadFileType.m3u8;
    return liveDetail;
  }

  static Future<String?> _getRedirectUrl(String shortUrl) async {
    Browser? browser;
    Page? page;
    try {
      logger.i('正在启动本地浏览器以解析链接 ...');
      (browser, page) = await CommonUtils.runBrowser(url: shortUrl, keyname: _keyname);
      final finalUrl = page.url;
      logger.i('浏览器解析完成，最终链接: $finalUrl');
      return finalUrl;
    } catch (e) {
      logger.e('使用浏览器解析链接失败', error: e);
      return null;
    } finally {
      logger.i('关闭浏览器');
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
    final apiUrl = 'https://alive-interact.alicdn.com/livedetail/common/$feedId';
    try {
      final response = await _dio.get(apiUrl);
      if (response.statusCode == 200 && response.data != null) {
        String responseBody = response.data.toString();
        int startIndex = responseBody.indexOf('{');
        int endIndex = responseBody.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          String jsonString = responseBody.substring(startIndex, endIndex + 1);
          final jsonData = jsonDecode(jsonString);
          return LiveDetail(
            replayUrl: jsonData['replayUrl'],
            title: jsonData['title'],
            liveId: jsonData['liveId'].toString(),
            duration: 0,
          );
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

  static Future<bool> _getM3u8TotalSize(LiveDetail liveDetail) async {
    try {
      final response = await _dio.get(liveDetail.replayUrl);
      if (response.statusCode != 200 || response.data == null) {
        return false;
      }
      final lines = (response.data as String).split('\n');
      final segmentUrls = <String>[];
      final m3u8Uri = Uri.parse(liveDetail.replayUrl);
      var duration = 0.0;
      for (final line in lines) {
        if (line.startsWith('#EXTINF:')) {
          final valueString = line.split(':')[1].split(',')[0];
          duration += double.parse(valueString);
        }
        if (line.isNotEmpty && !line.startsWith('#')) {
          Uri segmentUri;
          if (line.startsWith('http')) {
            segmentUri = Uri.parse(line);
          } else {
            // Handle relative paths
            segmentUri = m3u8Uri.resolve(line);
          }
          segmentUrls.add(segmentUri.toString());
        }
      }
      if (segmentUrls.isEmpty) {
        return false;
      }

      double totalSize = 0;
      var firstUrl = segmentUrls.first;
      try {
        final res = await _dio.head(firstUrl);
        if (res.statusCode == 200) {
          final length = res.headers.value('content-length');
          if (length != null) {
            totalSize = double.parse(length) * segmentUrls.length;
          }
        }
      } catch (e) {
        logger.e('获取片段大小失败: $firstUrl, 错误: $e');
      }

      if (totalSize == 0) {
        return false;
      }

      liveDetail.duration = duration.round();
      liveDetail.size = totalSize.toInt();
      return true;
    } catch (e, stackTrace) {
      logger.e('计算 m3u8 总大小失败', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
