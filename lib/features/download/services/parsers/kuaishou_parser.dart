import 'dart:convert';

import 'package:live_down/core/configs/app_cookie.dart';
import 'package:live_down/core/utils/common.dart';
import 'package:live_down/features/download/models/download_task.dart';
import 'package:live_down/features/download/models/live_detail.dart';
import 'package:live_down/core/services/logger_service.dart';
import 'package:puppeteer/puppeteer.dart';

class KuaishouParser {
  static const String _keyname = 'kuaishou';
  static Future<LiveDetail> parse(String shareText) async {
    final shortUrl = _extractShortUrl(shareText);
    if (shortUrl == null) {
      throw DownloadError('在分享文本中找不到有效的快手短链接');
    }
    logger.i('提取到短链接: $shortUrl');
    var liveDetail = LiveDetail();
    await _getRedirectUrl(shortUrl, liveDetail);
    liveDetail.platform = VideoPlatform.kuaishou;
    liveDetail.fileType = DownloadFileType.mp4;
    return liveDetail;
  }

  static String? _extractShortUrl(String text) {
    final regex = RegExp(r'https?://v\.kuaishou\.com/([a-zA-Z0-9]+)');
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  static Future<void> _getRedirectUrl(String shortUrl, LiveDetail liveDetail) async {
    Browser? browser;
    Page? page;
    try {
      logger.i('正在启动本地浏览器以解析链接 ...');
      (browser, page) = await CommonUtils.runBrowser(
          url: shortUrl,
          keyname: _keyname,
          onRequest: (request) {
            if (request.url.contains('.mp4')) {
              logger.i('捕获到视频流链接: ${request.url}');
            }
          },
          onResponse: (response) async {
            if (response.request.url.startsWith("https://v.m.chenzhongtech.com/rest/wd/ugH5App/recommend/photos")) {
              final data = jsonDecode(await response.text);
              final feedinfo = data['data']['finishPlayingRecommend']['feeds'][0];
              final videourl = feedinfo['mainMvUrls'][0]['url'];
              final coverurl = feedinfo['coverUrls'][0]['url'];
              final title = feedinfo['caption'];
              final duration = feedinfo['duration'];
              logger.i('捕获到视频流链接: ${response.request.url} $videourl $coverurl $title $duration');
              liveDetail.replayUrl = videourl;
              liveDetail.coverUrl = coverurl;
              liveDetail.title = title;
              liveDetail.duration = duration/1000;
              liveDetail.liveId = feedinfo['photoId'];
            }
          });
      final finalUrl = page.url!;
      logger.i('redirect url: $finalUrl');
      final uri = Uri.parse(finalUrl);
      String? photoId = uri.queryParameters['photoId'];
      final videoid = photoId;
      logger.i('视频id: $videoid');
      //check if the page contains "马上登录"
      if (await page.evaluate('document.querySelector("button.pl-btn")') != null) {
        //get the text of the button
        final buttonText = await page.evaluate('document.querySelector("button.pl-btn").innerText');
        if (buttonText == '马上登录') {
          //click the button
          await page.evaluate('document.querySelector("button.pl-btn").click()');
          //wait for the page to load
          await page.waitForNavigation(wait: Until.networkIdle);
          //get the final url
          // final finalUrl = page.url;
          // logger.i('浏览器解析完成，最终链接: $finalUrl');
        }
      }
      //catch page url req for type mp4

      //keep waiting
      while (liveDetail.replayUrl.isEmpty) {
        final url = page.url;
        logger.i('当前url: $url');
        final videokey = 'VisionVideoDetailPhoto:{$videoid}';
        //check  if  the page contains the videokey in window.__APOLLO_STATE__
        final videoState = await page.evaluate('window.__APOLLO_STATE__');
        logger.i('videoState: $videoState');
        if (videoState != null) {
          final clients = videoState['defaultClient'];
          if (clients != null) {
            final data = clients[videokey];
            if (data != null) {
              final coverurl = data['coverUrl'];
              final videoUrl = data['photoUrl'];
              final title = data['caption'];
              final duration = data['duration'];
              logger.i('视频已加载完成: $videoState $coverurl $videoUrl $title $duration');
              liveDetail.replayUrl = videoUrl;
              liveDetail.coverUrl = coverurl;
              liveDetail.title = title;
              liveDetail.duration = duration/1000;
              liveDetail.liveId = data['photoId'];
              //save all the page cookies
              final cookies = await page.cookies();
              logger.i('cookies: $cookies');
              //save the cookies to a file
              await AppCookie.saveCookies(cookies, 'kuaishou');
            }
          }
        }
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      logger.e('使用浏览器解析链接失败', error: e);
      return;
    } finally {
      logger.i('关闭浏览器');
      await browser?.close();
    }
  }
}
