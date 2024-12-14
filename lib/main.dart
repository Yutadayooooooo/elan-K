import 'dart:async';
import 'package:ami/app_define.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '/app_router.dart';
import '/navigation_service.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'package:ami/notifiers/address_notifier.dart';
import 'package:ami/notifiers/app_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppDefine.room) {
    // 横向き固定
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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