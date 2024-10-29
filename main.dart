import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:callkeep/callkeep.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:ami/app.dart';
import 'package:ami/firebase_options.dart';
import 'package:ami/notifiers/address_notifier.dart';
import 'package:ami/notifiers/app_notifier.dart';

/// For fcm background message handler.
final FlutterCallkeep _callKeep = FlutterCallkeep();
bool _callKeepInited = false;

/*
{
    "uuid": "xxxxx-xxxxx-xxxxx-xxxxx",
    "caller_id": "+8618612345678",
    "caller_name": "hello",
    "caller_id_type": "number", 
    "has_video": false,

    "extra": {
        "foo": "bar",
        "key": "value",
    }
}
*/

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  var payload = message.data;
  var callerId = payload['caller_id'] as String;
  var callerName = payload['caller_name'] as String;
  var uuid = payload['uuid'] as String;
  var hasVideo = payload['has_video'] == "true";
  final callUUID = uuid ?? Uuid().v4();
  _callKeep.on(CallKeepPerformAnswerCallAction(), (event) {
    // 通話を受け入れる処理
    print(
        'backgroundMessage: CallKeepPerformAnswerCallAction ${event.callUUID}');

    Timer(const Duration(seconds: 1), () {
      print(
          '[setCurrentCallActive] $event.callUUID, callerId: $callerId, callerName: $callerName');
      _callKeep.setCurrentCallActive(event.callUUID!);
    });
  });

  _callKeep.on(CallKeepPerformEndCallAction(), (event) {
    print('backgroundMessage: CallKeepPerformEndCallAction ${event.callUUID}');
  });

  if (!_callKeepInited) {
    _callKeep.setup(
        null,
        <String, dynamic>{
          'ios': {
            'appName': 'CallKeepDemo',
          },
          'android': {
            'alertTitle': 'Permissions required',
            'alertDescription':
            'This application needs to access your phone accounts',
            'cancelButton': 'Cancel',
            'okButton': 'ok',
            'foregroundService': {
              'channelId': 'com.company.my',
              'channelName': 'Foreground service for my app',
              'notificationTitle': 'My app is running on background',
              'notificationIcon':
              'Path to the resource icon of the notification',
            },
          },
        },
        backgroundMode: true);
    _callKeepInited = true;
  }

  print('backgroundMessage: displayIncomingCall ($callerId)');
  _callKeep.displayIncomingCall(
    callUUID,
    callerId,
    localizedCallerName: callerName,
    hasVideo: hasVideo,
  );
  _callKeep.backToForeground();
}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) {
  Logger logger = Logger();
  logger.d('backgroundMessage: message => ${message.toString()}');

  // Handle data message
  var data = message.data;
  var callerId = data['caller_id'] ?? message.senderId ?? "No Sender Id";
  var callerName = data['caller_name'] as String;
  var callUUID = data['uuid'] ?? const Uuid().v4();
  var hasVideo = data['has_video'] == "true";

  _callKeep.on(CallKeepPerformAnswerCallAction(), (event) {
    logger.d(
        'backgroundMessage: CallKeepPerformAnswerCallAction ${event.callUUID}');
    Timer(const Duration(seconds: 1), () {
      logger.d(
          '[setCurrentCallActive] $callUUID, callerId: $callerId, callerName: $callerName');
      _callKeep.setCurrentCallActive(callUUID);
    });
    //_callKeep.endCall(event.callUUID);
  });

  _callKeep.on(CallKeepPerformEndCallAction(), (event) {
    logger
        .d('backgroundMessage: CallKeepPerformEndCallAction ${event.callUUID}');
  });

  if (!_callKeepInited) {
    _callKeep.setup(
        null,
        <String, dynamic>{
          'ios': {
            'appName': 'CallKeepDemo',
          },
          'android': {
            'alertTitle': 'Permissions required',
            'alertDescription':
            'This application needs to access your phone accounts',
            'cancelButton': 'Cancel',
            'okButton': 'ok',
            'foregroundService': {
              'channelId': 'com.company.my',
              'channelName': 'Foreground service for my app',
              'notificationTitle': 'My app is running on background',
              'notificationIcon':
              'Path to the resource icon of the notification',
            },
          },
        },
        backgroundMode: true);
    _callKeepInited = true;
  }

  logger.d('backgroundMessage: displayIncomingCall ($callerId)');
  _callKeep.displayIncomingCall(
    callUUID,
    callerId,
    localizedCallerName: callerName,
    hasVideo: hasVideo,
  );
  _callKeep.backToForeground();
  /*

  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
    logger.d('notification => ${notification.toString()}');
  }

  // Or do other work.
  */
  return Future.value(null);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
  Logger.level = Level.all;
  print('main');
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppStore()),
      ChangeNotifierProvider(create: (_) => AddressStore()),
    ],
    child: App(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome to Flutter',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class Call {
  Call(this.number);

  String number;
  bool held = false;
  bool muted = false;
}

class _MyAppState extends State<HomePage> {
  final FlutterCallkeep _callKeep = FlutterCallkeep();
  Map<String, Call> calls = {};

  String newUUID() => Uuid().v4();

  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  void iOS_Permission() {
    // _firebaseMessaging.requestNotificationPermissions(
    //     IosNotificationSettings(sound: true, badge: true, alert: true));
    // _firebaseMessaging.onIosSettingsRegistered
    //     .listen((IosNotificationSettings settings) {
    //   print('Settings registered: $settings');
    // });
  }

  void removeCall(String callUUID) {
    setState(() {
      calls.remove(callUUID);
    });
  }

  void setCallHeld(String callUUID, bool held) {
    setState(() {
      calls[callUUID]?.held = held;
    });
  }

  void setCallMuted(String callUUID, bool muted) {
    setState(() {
      calls[callUUID]?.muted = muted;
    });
  }

  Future<void> answerCall(CallKeepPerformAnswerCallAction event) async {
    final String callUUID = event.callUUID!;
    final String number = calls[callUUID]!.number;
    print('[answerCall] $callUUID, number: $number');
    Timer(const Duration(seconds: 1), () {
      print('[setCurrentCallActive] $callUUID, number: $number');
      _callKeep.setCurrentCallActive(callUUID);
    });
  }

  Future<void> endCall(CallKeepPerformEndCallAction event) async {
    print('endCall: ${event.callUUID}');
    removeCall(event.callUUID!);
  }

  Future<void> didPerformDTMFAction(CallKeepDidPerformDTMFAction event) async {
    print('[didPerformDTMFAction] ${event.callUUID}, digits: ${event.digits}');
  }

  Future<void> didReceiveStartCallAction(CallKeepDidReceiveStartCallAction event,) async {
    final call = event;
    if (call.handle == null) {
      // @TODO: sometime we receive `didReceiveStartCallAction` with handle` undefined`
      return;
    }
    final String callUUID = call.callUUID ?? newUUID();
    setState(() {
      calls[callUUID] = Call(call.handle!);
    });
    print('[didReceiveStartCallAction] $callUUID, number: ${call.handle}');

    _callKeep.startCall(callUUID, call.handle!, call.handle!);

    Timer(const Duration(seconds: 1), () {
      print('[setCurrentCallActive] $callUUID, number: ${call.handle}');
      _callKeep.setCurrentCallActive(callUUID);
    });
  }

  Future<void> didPerformSetMutedCallAction(CallKeepDidPerformSetMutedCallAction event) async {
    final String number = calls[event.callUUID]!.number;
    print(
        '[didPerformSetMutedCallAction] ${event.callUUID}, number: $number (${event.muted})');

    setCallMuted(event.callUUID!, event.muted!);
  }

  Future<void> didToggleHoldCallAction(CallKeepDidToggleHoldAction event) async {
    final String number = calls[event.callUUID]!.number;
    print(
        '[didToggleHoldCallAction] ${event.callUUID}, number: $number (${event.hold})');

    setCallHeld(event.callUUID!, event.hold!);
  }

  Future<void> hangup(String callUUID) async {
    _callKeep.endCall(callUUID);
    removeCall(callUUID);
  }

  Future<void> setOnHold(String callUUID, bool held) async {
    _callKeep.setOnHold(callUUID, held);
    final String handle = calls[callUUID]!.number;
    print('[setOnHold: $held] $callUUID, number: $handle');
    setCallHeld(callUUID, held);
  }

  Future<void> setMutedCall(String callUUID, bool muted) async {
    _callKeep.setMutedCall(callUUID, muted);
    final String handle = calls[callUUID]!.number;
    print('[setMutedCall: $muted] $callUUID, number: $handle');
    setCallMuted(callUUID, muted);
  }

  Future<void> updateDisplay(String callUUID) async {
    final String number = calls[callUUID]!.number;
    // Workaround because Android doesn't display well displayName, se we have to switch ...
    if (isIOS) {
      _callKeep.updateDisplay(callUUID,
          displayName: 'New Name', handle: number);
    } else {
      _callKeep.updateDisplay(callUUID,
          displayName: number, handle: 'New Name');
    }

    print('[updateDisplay: $number] $callUUID');
  }

  Future<void> displayIncomingCallDelayed(String number) async {
    Timer(const Duration(seconds: 3), () {
      displayIncomingCall(number);
    });
  }

  Future<void> displayIncomingCall(String number) async {
    final String callUUID = newUUID();
    setState(() {
      calls[callUUID] = Call(number);
    });
    print('Display incoming call now');
    final bool hasPhoneAccount = await _callKeep.hasPhoneAccount();
    if (!hasPhoneAccount) {
      await _callKeep.hasDefaultPhoneAccount(context, <String, dynamic>{
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
        'foregroundService': {
          'channelId': 'com.company.my',
          'channelName': 'Foreground service for my app',
          'notificationTitle': 'My app is running on background',
          'notificationIcon': 'Path to the resource icon of the notification',
        },
      });
    }

    print('[displayIncomingCall] $callUUID number: $number');
    _callKeep.displayIncomingCall(callUUID, number,
        handleType: 'number', hasVideo: false);
  }

  void didDisplayIncomingCall(CallKeepDidDisplayIncomingCall event) {
    var callUUID = event.callUUID!;
    var number = event.handle!;
    print('[displayIncomingCall] $callUUID number: $number');
    setState(() {
      calls[callUUID] = Call(number);
    });
  }

  void onPushKitToken(CallKeepPushKitToken event) {
    print('[onPushKitToken] token => ${event.token}');
  }

  @override
  void initState() {
    super.initState();
    _callKeep.on(CallKeepDidDisplayIncomingCall(), didDisplayIncomingCall);
    _callKeep.on(CallKeepPerformAnswerCallAction(), answerCall);
    _callKeep.on(CallKeepDidPerformDTMFAction(), didPerformDTMFAction);
    _callKeep.on(
        CallKeepDidReceiveStartCallAction(), didReceiveStartCallAction);
    _callKeep.on(CallKeepDidToggleHoldAction(), didToggleHoldCallAction);
    _callKeep.on(
        CallKeepDidPerformSetMutedCallAction(), didPerformSetMutedCallAction);
    _callKeep.on(CallKeepPerformEndCallAction(), endCall);
    _callKeep.on(CallKeepPushKitToken(), onPushKitToken);
    _callKeep.setup(context, <String, dynamic>{
      'ios': {
        'appName': 'CallKeepDemo',
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
        'foregroundService': {
          'channelId': 'jp.frinurse.ami',
          'channelName': 'Foreground service for my app',
          'notificationId': 5005,
          'notificationTitle': 'My app is running on background',
          'notificationIcon': 'Path to the resource icon of the notification',
        },
      },
    });

    Future(() async {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      final token = await messaging.getToken();
      print('[FCM] token => ${token!}');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        var payload = message.data;
        var callerId = payload['caller_id'] as String;
        var callerName = payload['caller_name'] as String;
        var uuid = payload['uuid'] as String;
        var hasVideo = payload['has_video'] == "true";
        final callUUID = uuid ?? Uuid().v4();
        setState(() {
          calls[callUUID] = Call(callerId);
        });
        _callKeep.displayIncomingCall(
          callUUID,
          callerId,
          localizedCallerName: callerName,
          hasVideo: hasVideo,
        );

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
        }
      });
    });

  }

  Widget buildCallingWidgets() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: calls.entries
            .map((MapEntry<String, Call> item) =>
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Text('number: ${item.value.number}'),
                  Text('uuid: ${item.key}'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () async {
                          setOnHold(item.key, !item.value.held);
                        },
                        child: Text(item.value.held ? 'Unhold' : 'Hold'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          updateDisplay(item.key);
                        },
                        child: const Text('Display'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setMutedCall(item.key, !item.value.muted);
                        },
                        child: Text(item.value.muted ? 'Unmute' : 'Mute'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          hangup(item.key);
                        },
                        child: const Text('Hangup'),
                      ),
                    ],
                  )
                ]))
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: () async {
                  displayIncomingCall('10086');
                },
                child: const Text('Display incoming call now'),
              ),
              ElevatedButton(
                onPressed: () async {
                  displayIncomingCallDelayed('10086');
                },
                child: const Text('Display incoming call now in 3s'),
              ),
              buildCallingWidgets()
            ],
          ),
        ),
      ),
    );
  }
}
