import 'dart:async';
import 'dart:io';
import 'package:eraser/eraser.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:ami/app_router.dart';
import 'app_define.dart';
import 'app_manager.dart';
import 'firebase_options.dart';
import 'notifiers/app_notifier.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Handling a background message ${message.messageId}');
  print('Message title: ${message.notification?.title}, body: ${message.notification?.body}, data: ${message.data}');

  if (message.data.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    if (message.data['title'] == 'call') {
      prefs.setString('incoming_call_data', message.data.toString());
    }
  }
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ami',
      debugShowCheckedModeBanner: false,
      locale: const Locale("ja", "JP"),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale("ja", "JP"),
      ],
      home: GestureDetector(
        onTap: () => primaryFocus?.unfocus(),
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.0,
          child: AppPage(),
        ),
      ),
    );
  }
}

class AppPage extends StatefulWidget {
  @override
  _AppPageState createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> with WidgetsBindingObserver {
  late final Uuid _uuid;
  late GoRouter _router;
  late final FirebaseMessaging _firebaseMessaging;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    _uuid = const Uuid();
    initFirebase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('*********************************');
      print('******************   app resumed   ******************');
      print('*********************************');
    } else if (state == AppLifecycleState.paused) {
      print('*********************************');
      print('******************   app paused   ******************');
      print('*********************************');
    }
  }

  @override
  void dispose() {
    print('app dispose');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    _firebaseMessaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received a foreground message: ${message.messageId}');
      _handleMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleMessage(message);
    });

    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _firebaseMessaging.getToken().then((token) {
      print('Device Token FCM: $token');
      AppManager.fcmtoken = token;
    });
  }

  void _handleMessage(RemoteMessage message) {
    print('_handleMessage: ${message.data}');

    if (message.data['title'] == 'call') {
      final callerId = message.data['caller_id'];
      final callerName = message.data['caller_name'];
      print('Incoming call from $callerName ($callerId)');
    } else if (message.data['title'] == 'call_cancel') {
      print('Call cancelled');
    }
  }

  Future<int> _getElanLaunchType() async {
    int status = 10;
    final prefs = await SharedPreferences.getInstance();

    bool isInitialized = prefs.getBool("isInitialized") ?? false;
    if (!isInitialized) {
      return status;
    }

    status += 1;
    bool login = prefs.getBool("login") ?? false;
    if (!login) {
      return status;
    }
    status += 1;

    return status;
  }

  Future<int> _getLaunchType() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialize = prefs.getBool("isInitialized") ?? false;
    final isLogin = prefs.getBool("login") ?? false;
    context
        .read<AppStore>()
        .setIsInitialized(prefs.getBool("isInitialized") ?? false);
    context.read<AppStore>().setIsLoggedIn(prefs.getBool("login") ?? false);
    print(isInitialize);
    print(isLogin);
    _router = await AppRoute.createRouter(isInitialize, isLogin);
    return 1;
    if (AppDefine.elanApp) {
      return _getElanLaunchType();
    }
    int status = 0;

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    print('$appName, $packageName, $version, $buildNumber');

    bool isInitialized = prefs.getBool("isInitialized") ?? false;
    if (!isInitialized) {
      return status;
    }
    status = 1;
    bool login = prefs.getBool("login") ?? false;
    if (!login) {
      return status;
    }

    status = 2;
    var _load = await AppManager.loadSetting();
    if (_load) {
      if (AppManager.settings['MCSTYPE'] == '4') {
        status = 5;
      } else if (AppManager.settings['DISPTYPE'] == '1') {
        status = 3;
      } else if (AppManager.settings['DISPTYPE'] == '2') {
        status = 4;
      }
      if (AppManager.isManager) {
        status = 9;
      }
    }

    return status;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getLaunchType(),
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final hasData = snapshot.hasData;
        if (!hasData) {
          return Center(child: const CircularProgressIndicator());
        }

        return MaterialApp.router(
          title: 'ami',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale("ja", "JP"),
          ],
          routerConfig: _router,
        );
      },
    );
  }
}
