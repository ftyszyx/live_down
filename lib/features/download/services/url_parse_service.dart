import 'package:live_down/features/download/services/parsers/taobao_parser.dart';

import '../models/live_detail.dart';

class UrlParseService {

  /// Parses a share text/URL to extract video details like title and m3u8 URL.
  static Future<LiveDetail> parseUrl(String shareText) async {
    // 1. 根据分享文本判断平台
    if (shareText.contains('m.tb.cn')) {
      return await TaobaoParser.parse(shareText);
    } else {
      throw DownloadError('不支持的平台');
    }
  }
} 