import 'dart:convert';
import "package:intl/intl.dart";
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class AppDefine {
  // static final baseURL = 'https://mcs-a.com/frinurse/';
  static const amiURL = 'https://fun-talk.net/amiapp/';
  static final mcsaURL = 'https://mcs-a.com/frinurse/';
  static String get baseURL => _amiApp ? amiURL : mcsaURL;
  static const appLabel = 'このアプリ';
  static const elanApp = true;
  static const _amiApp = true;
  static bool get amiApp => _amiApp;

  // デバイスの画面サイズに基づいて自動判定
  static bool get room => _isTablet();

  // タブレット判定ロジック
  static bool _isTablet() {
    // プラットフォーム別の判定
    if (Platform.isIOS) {
      // iOS: iPadかどうかの判定は実行時に行う必要があるため、
      // 初期値としてtrueを返し、実際の判定は初期化時に行う
      return _tabletMode ?? true;
    } else if (Platform.isAndroid) {
      // Android: 画面サイズベースで判定
      return _tabletMode ?? true;
    } else {
      // その他のプラットフォーム（デスクトップなど）
      return true;
    }
  }

  // 実行時に設定される値
  static bool? _tabletMode;

  // 初期化時にデバイスタイプを設定
  static Future<void> setDeviceType(
      {required double screenWidth, required double screenHeight}) async {
    final shortSide = screenWidth < screenHeight ? screenWidth : screenHeight;
    final aspectRatio = screenWidth > screenHeight
        ? screenWidth / screenHeight
        : screenHeight / screenWidth;

    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // GT-10S-WHを強制的にタブレット扱いにする
      if (androidInfo.model == 'GT-10S-WH' ||
          androidInfo.model.contains('GT-10S') ||
          androidInfo.product == 'GT-10S-WH') {
        _tabletMode = true;
        return;
      }
    }

    // 通常の判定ロジック
    _tabletMode = shortSide >= 600 || aspectRatio <= 1.6;
  }

  // ライブ画像アップロード
  static bool useWebLiveImage = false;

  // SPO2結果表示
  static bool showSpo2 = false;

  static const kiyakuURL = 'https://happybell.biz/terms/index.html';
  static const policyURL = 'https://happybell.biz/privacy/index.html';
  static const signUpURL = 'https://happybell.biz/sign_up/index.html';
  static const companyURL = 'https://happybell.biz/service/index.html';
  static const licenseURL = 'https://happybell.biz/license/index.html';

  static const absenceSec1 = 30 * 1000;
  static const absenceSec2 = 60 * 1000;

  static getRMSToken() {
    initializeDateFormatting("ja_JP");
    final now = DateTime.now();
    var formatter = DateFormat('yyyyMMddHHmmss', "ja_JP");
    var formatted = formatter.format(now);
    final str = "telnurseapptoken$formatted";
    List<int> bytes = utf8.encode(str);
    return base64.encode(bytes);
  }

  static getDelegatorToken() {
    return 'hP5ppMqMwGeQ6Gh5MUAz7ZaBQT8WedxZ';
  }
}

class ImageName {
  static const connecting = 'assets/images/talk/connecting.png';
  static const roomCall = 'assets/images/room/call.gif';
  static const rusu = 'assets/images/talk/rusu.png';
  static const addrCall = 'assets/images/status/addr_call.png';
}
