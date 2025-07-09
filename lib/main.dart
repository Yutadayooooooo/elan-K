import 'package:ami/app_define.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'package:ami/notifiers/address_notifier.dart';
import 'package:ami/notifiers/app_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 画面サイズを取得してデバイスタイプを判定
  final window = WidgetsBinding.instance.window;
  final size = window.physicalSize / window.devicePixelRatio;
  await AppDefine.setDeviceType(
    screenWidth: size.width,
    screenHeight: size.height,
  );

  // デバイスタイプに応じて画面方向を設定
  if (AppDefine.room) {
    // タブレット: 横向き固定
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    // スマホ: 縦向き固定
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppStore()),
      ChangeNotifierProvider(create: (_) => AddressStore()),
    ],
    child: App(),
  ));
}
