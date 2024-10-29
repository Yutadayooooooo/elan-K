import 'dart:async';
import 'dart:io';
import 'package:eraser/eraser.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
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
import 'helpers/staff_helper.dart';
import 'notifiers/app_notifier.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  print('Message title: ${message.notification?.title}, body: ${message.notification?.body}, data: ${message.data}');

  // await Eraser.clearAppNotificationsByTag('notificationOfCall');
  if (message.data.isEmpty) {
    return;
  }


  if (message.data['title'] == 'call_cancel') {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    final cancelId = message.data['caller_id'].toString().replaceAll('_cancel', '');
    await hideCallkitIncoming(cancelId);
  } else if (message.data['title'] == 'call') {
    receiveFirebaseCallMessageBackground(message);
  }
}

Future<void> showCallkitIncoming(dynamic data) async {
  final params = AppHelper.callParams(data['caller_id'], data['caller_id'],
      data['caller_name'], 'https://fun-talk.net/amiapp/images/avater.png');
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

Future<void> receiveFirebaseCallMessageBackground(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Future.delayed(const Duration(milliseconds: 100), () async {
    await Eraser.clearAppNotificationsByTag('callnotification');
  });
  await FlutterCallkitIncoming.endAllCalls();

  showCallkitIncoming(message.data);
}

Future<void> listenFirebaseRemoteMessage(RemoteMessage message) async {
  print(
      '*********************    listen  Message title: ${message.notification?.title}, body: ${message.notification?.body}, data: ${message.data}');
  if (message.data['title'] == 'call_cancel') {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final cancelId = message.data['caller_id'].toString().replaceAll('_cancel', '');
    await hideCallkitIncoming(cancelId);
  } else if (message.data['title'] == 'call') {
  }
}

Future<void> hideCallkitIncoming(cancelId) async {
  var isCancel = false;
  var calls = await FlutterCallkitIncoming.activeCalls();
  if (calls is List) {
    if (calls.isNotEmpty) {
      print('DATA: $calls');
      if (calls[0]['id'] == cancelId) {
        isCancel = true;
      }
    } else {
      print('calls is empty');
      print(calls);
    }
  } else {
    print('calls is not list');
    print(calls);
  }
  if (!isCancel) {
    return;
  }

  print('push cancel : $cancelId');
  CallKitParams params = CallKitParams(
    id: cancelId,
  );
  // await FlutterCallkitIncoming.hideCallkitIncoming(params);
  await FlutterCallkitIncoming.endCall(cancelId);
  // await FlutterCallkitIncoming.endAllCalls();
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
  String? _currentUuid;
  late GoRouter _router;
  late final FirebaseMessaging _firebaseMessaging;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();

    _uuid = const Uuid();
    initFirebase();
    // initCurrentCall();
    listenerEvent(onEvent);
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
    FirebaseMessaging.onMessage.listen(listenFirebaseRemoteMessage);
    _firebaseMessaging.requestPermission();
    _firebaseMessaging.getToken().then((token) {
      print('Device Token FCM: $token');
      AppManager.fcmtoken = token;
    });
  }

  Future<dynamic> initCurrentCall() async {
    await requestNotificationPermission();
    //check current call from pushkit if possible
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        print('DATA: $calls');
        _currentUuid = calls[0]['id'];
        return calls[0];
      } else {
        _currentUuid = "";
        return null;
      }
    }
  }

  Future<void> requestNotificationPermission() async {
    await FlutterCallkitIncoming.requestNotificationPermission({
      "rationaleMessagePermission":
          "Notification permission is required, to show notification.",
      "postNotificationMessageRequired":
          "Notification permission is required, Please allow notification permission from setting."
    });
  }

  Future<void> listenerEvent(void Function(CallEvent) callback) async {
    try {
      FlutterCallkitIncoming.onEvent.listen((event) async {
        print('HOME: $event');
        switch (event!.event) {
          case Event.actionCallIncoming:
            // TODO: received an incoming call
            break;
          case Event.actionCallStart:
            // TODO: started an outgoing call
            // TODO: show screen calling in Flutter
            break;
          case Event.actionCallAccept:
            print(
                '************************   action call ************************');
            AppManager.acceptId = event.body['extra']['userId'];
            // context.read<AppStore>().setSelectCode(event.body['extra']['userId']);
            // TODO: accepted an incoming call
            // TODO: show screen calling in Flutter
            //   NavigationService.instance
            //       .pushNamedIfNotCurrent(AppRoute.callingPage, args: event.body);
            break;
          case Event.actionCallDecline:
            // TODO: declined an incoming call
            //   await requestHttp("ACTION_CALL_DECLINE_FROM_DART");
            print(
                '************************   action call decline ************************');
            break;
          case Event.actionCallEnded:
            // TODO: ended an incoming/outgoing call
            print(
                '************************   action call ended ************************');
            break;
          case Event.actionCallTimeout:
            print(
                '************************   action call timeout ************************');
            _onActionCallTimeout(event);
            break;
          case Event.actionCallCallback:
            // TODO: only Android - click action `Call back` from missed call notification
            break;
          case Event.actionCallToggleHold:
            // TODO: only iOS
            break;
          case Event.actionCallToggleMute:
            // TODO: only iOS
            break;
          case Event.actionCallToggleDmtf:
            // TODO: only iOS
            break;
          case Event.actionCallToggleGroup:
            // TODO: only iOS
            break;
          case Event.actionCallToggleAudioSession:
            // TODO: only iOS
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            // TODO: only iOS
            break;
          case Event.actionCallCustom:
            break;
        }
        callback(event);
      });
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> _onActionCallTimeout(CallEvent event) async {
    if (Platform.isAndroid) {
      print(event.body);
      final uuid = event.body['id'];
      final name = event.body['nameCaller'];

      await FlutterCallkitIncoming.endAllCalls();
      final params = CallKitParams(
        id: uuid,
        nameCaller: name,
        avatar: event.body['avatar'],
        missedCallNotification: const NotificationParams(
          subtitle: '不在着信',
          callbackText: '発信',
        ),
      );
      // await FlutterCallkitIncoming.showMissCallNotification(params);
    }
  }

  void onEvent(CallEvent event) {
    if (!mounted) return;
    // print('---\n${event.toString()}\n');
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
        // }
        // if (AppManager.settings['MASPROSENSOR'] == "1") {
        //   status = 10;
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
