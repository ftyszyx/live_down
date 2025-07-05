import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:puppeteer/protocol/network.dart';

class AppCookie {
  static Future<String> getCookiePath(String keyname) async {
    final userFolder = await getApplicationDocumentsDirectory();
    return join(userFolder.path, 'cookies', '$keyname.json');
  }

  static Future<void> saveCookies(List<Cookie> cookies, String keyname) async {
    final cookieFile = File(await getCookiePath(keyname));
    await cookieFile.writeAsString(jsonEncode(cookies));
  }

  static Future<List<Cookie>> getCookies(String keyname) async {
    final cookieFile = File(await getCookiePath(keyname));
    if (!cookieFile.existsSync()) {
      return [];
    }
    return jsonDecode(cookieFile.readAsStringSync());
  }
}
