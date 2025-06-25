import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ami/helpers/widget_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:marquee/marquee.dart';
import 'package:video_player/video_player.dart';

import '../../app_define.dart';
import '../../app_manager.dart';
import '../../app_router.dart';
import '../../models/address_model.dart';
import '../../notifiers/address_notifier.dart';
import '../../services/audio_service.dart';
import '../../services/socket_io_service.dart';
import '/pages/room/room_talk_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/peer_service.dart';
import '../../widgets/clock_widget.dart';

class RoomPage extends StatefulWidget {
  @override
  _RoomPageState createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage>
    with WidgetsBindingObserver, SocketIOServiceDelegate {
  bool _init = true;
  bool _active = true;
  bool _tapping = false;
  String _version = '1.0';
  Timer? _sleeptimer;
  Timer? _toSettingTimer;
  Timer? _allTalkingTimer;
  Timer? _getInfoTimer;
  Timer? _slideShowTimer;
  SocketIOService socketservice = SocketIOService();
  AudioService audio = AudioService();
  bool _isconnect = false;
  List<Address> addressList = [];
  bool _talking = false;
  bool _isSleep = false;
  bool _isChangeBrightness = false;
  double _currentBrightness = 1.0;
  double _sleepBrightness = 0.5;
  String _statusImage = '';
  Peer peer = Peer();
  bool _isVideoLoop = false;
  VideoPlayerController? _controller;

  var _safetyCheckIds = [];
  String _infoMessage = '';
  String _infoVideo = '';
  var _imageFiles = [];
  var _imageFileIndex = -1;
  double _imageOpacity = 0.0;

  bool _debugToast = false;

  void _showDebugToast(String message) {
    if (_debugToast) {
      AppManager.toast(message);
    }
  }

  @override
  void initState() {
    super.initState();
    print('[DEBUG PRINT] room initState');

    AppManager.setStatusBarHidden(false);
    WidgetsBinding.instance.addObserver(this);
    peer.onLocalStream = _onLocalStream;
    peer.onOffer = _onOffer;
    peer.onAnswer = _onAnswer;
    peer.onAddRemoteStream = _onAddRemoteStream;
    peer.onIceCandidate = _onIceCandidate;

    socketservice.delegate = this;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Future(() async {
      _brightnessSetting();
    });
  }

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    print('room didChangeDependencies');

    if (_init) {
      _init = false;

      var load = await AppManager.loadSetting();
      if (!load) {
        _logout();
      }

      _loadAddress();
      AppManager.loadAutoReceive();

      AppManager.requestPermission();
      socketservice.startConnectTimer();
      _version = await AppManager.appVersion();
      _startGetInfoTimer(isGet: true);
    }

    if (AppManager.appsettings['SLEEP_MODE'] == '1' ||
        AppManager.appsettings['CLOCKDISP'] == '1') {
      print('isSleep');
      setState(() {
        _isSleep = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("room life cycle state -> ${state}");
    // setState(() {
    //   _notification = state;
    // });
    if (state == AppLifecycleState.resumed) {
      print('resumed');
      socketservice.reconnect = true;
      socketservice.startConnectTimer();
      _startGetInfoTimer();
    } else if (state == AppLifecycleState.paused) {
      // sensorService.stopWatch();
      _active = false;
      _stopTimers();
      if (_sleeptimer != null) {
        _sleeptimer!.cancel();
      }

      socketservice.reconnect = false;
      socketservice.stopTimer();
      socketservice.disconnect();
      setState(() {
        _isconnect = false;
      });
    }
  }

  @override
  void dispose() {
    print('room dispose');
    // socketservice.delegate = null;
    WidgetsBinding.instance.removeObserver(this);

    _controller?.dispose();
    super.dispose();
  }

  void _initPeer() {
    peer = Peer();
    peer.onLocalStream = _onLocalStream;
    peer.onOffer = _onOffer;
    peer.onAnswer = _onAnswer;
    peer.onAddRemoteStream = _onAddRemoteStream;
    peer.onIceCandidate = _onIceCandidate;
  }

  void _disposePeer() {
    peer.close();
    peer.onLocalStream = null;
    peer.onOffer = null;
    peer.onAnswer = null;
    peer.onAddRemoteStream = null;
    peer.onIceCandidate = null;
  }

  void _stopGetInfoTimer() {
    if (_getInfoTimer != null) {
      _getInfoTimer!.cancel();
      _getInfoTimer = null;
    }
    _imageFileIndex = -1;
    _imageFiles = [];
  }

  void _startGetInfoTimer({bool isGet = false}) {
    print('start get info timer $isGet');
    _stopGetInfoTimer();
    if (isGet) {
      _getInfo();
    }

    _getInfoTimer = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
      _getInfo();
    });
  }

  Future<void> _getInfo() async {
    var url = '${AppDefine.baseURL}api/info?code=${AppManager.delegatorCode}&mst_id=${AppManager.myId}';
    _showDebugToast(url);
    print(url);
    print(DateTime.now());
    final dio = Dio();
    var data = await dio.get(url,)
        .then((response) {
      print(response.data);
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    if (data == null) {
      return;
    }

    _infoMessage = data['message'].toString();

    final currentVideo = _infoVideo;
    final currentVideoLoop = _isVideoLoop;
    _infoVideo = data['video'].toString();
    var _fileChanged = false;
    if (_imageFiles.length != data['files'].length) {
      _fileChanged = true;
    } else {
      for (var i = 0; i < data['files'].length; i++) {
        if (_imageFiles[i] != data['files'][i]) {
          _fileChanged = true;
          break;
        }
      }
    }
    if (_fileChanged) {
      _imageFileIndex = -1;
      if (_imageFiles.isNotEmpty) {
        _stopMovie();
      }
      _imageFiles = data['files'];
      _startImageAnimation();
    }

    if (_imageFiles.isNotEmpty) {
      _infoVideo = '';
    }

    _isVideoLoop = data['video_loop'].toString() == '1';

    if (_infoVideo.isNotEmpty && (currentVideo != _infoVideo || currentVideoLoop != _isVideoLoop)) {
      _startMovie();
    }

    if (mounted) {
      setState(() {
      });
    }
  }

  Future<void> _logout() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool('login', false);
    // Todo ログインページへ
  }

  void _loadAddress() {
    SharedPreferences.getInstance().then((prefs) {
      String? addressString = prefs.getString('address');
      // print(addressString);
      if (addressString != null) {
        var addressJson = json.decode(addressString);
        context.read<AddressStore>().setAddressList(addressJson);
        // var storedAddressList = Address.fromJsonList(addressJson);

        // setState(() {
        //   addressList = storedAddressList;
        // });
      }
    });
  }

  void _disconnect() {
    socketservice.stopTimer();
    socketservice.delegate = null;
    socketservice.reconnect = false;
    socketservice.disconnect();
    setState(() {
      _isconnect = false;
    });
  }

  Future<void> _toSetting() async {
    _stopTimers();
    _disconnect();
    _safetyCheckIds.clear();
    context.read<AddressStore>().clear();
    _active = false;
    await context.push(AppRoute.settingPage);
    _active = true;
    print('from setting to room');
    socketservice.reconnect = true;
    socketservice.delegate = this;
    socketservice.startConnectTimer();
    _startGetInfoTimer(isGet: true);
    _startImageAnimation();
  }

  void _stopTimers() {
    if (_sleeptimer != null) {
      _sleeptimer!.cancel();
    }
    if (_allTalkingTimer != null) {
      _allTalkingTimer!.cancel();
      _allTalkingTimer = null;
    }
    _stopMovie();
    _stopGetInfoTimer();
    _stopImageAnimation();
  }

  Future<void> _tap() async {
    if (!socketservice.isConnect()) {
      AppManager.toast("接続されていません。", bgColor: Colors.blue);
      return;
    }
    if (_tapping) {
      return;
    }
    _tapping = true;
    _active = false;
    var list = context.read<AddressStore>().addressList;
    AppManager.selectUser = list[0];
    AppManager.status = AppStatus.Call;

    if (_sleeptimer != null) {
      _sleeptimer!.cancel();
    }
    _stopGetInfoTimer();
    _stopImageAnimation();
    _controller?.pause();
    _safetyCheckEnd();

    await context.push(AppRoute.roomTalkPage);

    if (AppManager.allTalking) {
      setState(() {

      });
      _allTalkingTimer = Timer.periodic(const Duration(minutes: 5), (Timer timer) {
        setState(() {
          AppManager.allTalking = false;
        });
      });
    }

    _startGetInfoTimer();
    _startImageAnimation();
    print('[DEBUG PRINT] from roomtalk');
    audio.stopCall();
    audio.stopRingtone();
    _active = true;
    socketservice.delegate = this;
    _tapping = false;
  }

  void _showSleep() {
    _getBrightness();
    setState(() {
      _isSleep = true;
    });
    _setBrightness(_sleepBrightness);
    if (_sleeptimer != null) {
      _sleeptimer!.cancel();
    }
  }

  void _hideSleep() {
    if (_isChangeBrightness) {
      _setBrightness(_currentBrightness);
    }
    setState(() {
      _isSleep = false;
    });
    if (_safetyCheckIds.isNotEmpty) {
      socketservice.io.emit("safety_check_stop", []);
      _safetyCheckIds.clear();
      peer.close();
    }

    _sleeptimer =
        Timer.periodic(const Duration(milliseconds: 5000), (Timer timer) {
      if (AppManager.status == AppStatus.None) {
        _showSleep();
      }
    });
  }

  void _brightnessSetting() {
    _isChangeBrightness = false;
    _sleepBrightness = 0.5;
    if (AppManager.appsettings['SLEEPMODEBRIGHTNESS'] != '0') {
      _isChangeBrightness = true;
      if (AppManager.appsettings['SLEEPMODEBRIGHTNESS'] == '2') {
        _sleepBrightness = 0.2;
      }
    }
    _setBrightness(_sleepBrightness);
  }

  Future<void> _getBrightness() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
    } catch (e) {
      debugPrint(e.toString());
      throw 'Failed to get brightness';
    }
  }

  Future<void> _setBrightness(double brightness) async {
    print('set brightness ${brightness}');
    if (!_isChangeBrightness) {
      return;
    }
    try {
      await ScreenBrightness().setScreenBrightness(brightness);
    } catch (e) {
      debugPrint(e.toString());
      throw 'Failed to set brightness';
    }
  }

  void _startImageAnimation() {
    _stopImageAnimation();
    _slideShow();
    _slideShowTimer = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
      _slideShow();
    });
  }

  void _stopImageAnimation() {
    if (_slideShowTimer != null) {
      _slideShowTimer?.cancel();
      _slideShowTimer = null;
    }
  }

  void _slideShow() {
    if (mounted && _imageFiles.isNotEmpty) {
      if (_imageFiles.length == 1) {
        setState(() {
          _imageFileIndex = 0;
          _imageOpacity = 1.0;
        });
      } else {
        setState(() {
          _imageOpacity = 0.0;
        });
        Future.delayed(Duration(milliseconds: 1000), () {
          _imageFileIndex = (_imageFileIndex + 1) < _imageFiles.length ? _imageFileIndex + 1 : 0;
          setState(() {
            _imageOpacity = 1.0;
          });
        });
      }
    }
  }

  void _startMovie() {
    _controller?.dispose();
    final url = '${AppDefine.baseURL}image?path=${_infoVideo}';
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
    )..initialize().then((_) {
        // 動画が初期化されたら再描画
        setState(() {});
        // 動画を自動再生
        _controller!.play();
        _controller!.setLooping(_isVideoLoop); // ループ再生を有効化
      });
  }

  void _stopMovie() {
    _infoVideo = '';
    if (mounted) {
      setState(() {

      });
    }
    _controller?.dispose();
  }

  Future<void> _receive(String udid) async {
    print(DateTime.now());
    print('[DEBUG PRINT] room receive ' + udid);
    if (_isSleep) {
      _setBrightness(0.8);
    }
    _safetyCheckEnd();
    AppManager.selectUser = Address.fromJson({
      "id": udid,
      "name": '',
      "status": "0",
      "call": "1",
      "called": "0",
      "userType": "0",
      "photo": ""
    });
    _active = false;
    _stopGetInfoTimer();
    _controller?.pause();
    _safetyCheckEnd();
    await context.push(AppRoute.roomTalkPage);

    _startGetInfoTimer();
    print('[DEBUG PRINT] from roomtalk');
    _tapping = false;
    _active = true;
    if (_isSleep) {
      _setBrightness(0.5);
    }
  }

  void _receiveSafetyCheck(String udid) {
    // if (AppManager.appsettings['SLEEP_MODE'] != '1') {
    //   socketservice.io.emit("safety_check_error", [udid]);
    //   return;
    // }
    // if (!_isSleep) {
    //   socketservice.io.emit("safety_check_error", [udid]);
    //   return;
    // }
    _showDebugToast("_receiveSafetyCheck");
    if (!_active) {
      _showDebugToast("_receiveSafetyCheck not active");
      socketservice.io.emit("safety_check_error", [udid]);
      return;
    }

    if (_safetyCheckIds.isNotEmpty) {
      _showDebugToast("_receiveSafetyCheck _safetyCheckIds.isNotEmpty");
      socketservice.io.emit("safety_check_error", [udid]);
      return;
    }
    _safetyCheckIds.add(udid);
    peer.invite(udid, 'sendonly', true);
  }

  Future<void> _onAutoReceives() async {
    var response = await _requestAutoReceives();
    if (response == null) {
      return;
    }
    if (response['status'] != 'ok') {
      return;
    }
    var values = response['values'];
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('autoreceive', json.encode(values));
    AppManager.loadAutoReceive();
  }

  Future<dynamic> _requestAutoReceives() async {
    var token = AppDefine.getRMSToken();
    var url = AppDefine.baseURL +
        'app/v4/auto_receives.php?delegatorCode=' +
        AppManager.delegatorCode +
        '&userID=' +
        AppManager.myId +
        '&token=' +
        token;
    print(url);
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      return jsonResponse;
    }
    return null;
  }

  void _receiveSafetyCheckEnd(String udid) {
    _safetyCheckEnd();
  }

  void _safetyCheckEnd() {
    if (_safetyCheckIds.isNotEmpty) {
      socketservice.io.emit("safety_check_stop", []);
    }
    _safetyCheckIds.clear();
    _disposePeer();
    _initPeer();
  }

  Future<void> _onCallButton() async {
    _safetyCheckEnd();
    _tap();
  }

  bool _isSleepMode() {
    List<String> startParts = AppManager.appsettings['SLEEP_START'].split(':');
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);
    List<String> endParts = AppManager.appsettings['SLEEP_END'].split(':');
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);

    final start = TimeOfDay(hour: startHour, minute: startMinute);
    final end = TimeOfDay(hour: endHour, minute: endMinute);
    final now = TimeOfDay.now();

    // 判定
    final isWithinRange = _isTimeWithinRange(now, start, end);

    return isWithinRange;
  }

  /// 現在時刻が指定した範囲内にあるかを判定する関数
  bool _isTimeWithinRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // 終了時刻が開始時刻よりも小さい場合（範囲が日をまたぐ場合）
    if (endMinutes < startMinutes) {
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    } else {
      // 通常の範囲内判定
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    const iconSize = 50.0;
    final Size size = MediaQuery.of(context).size;
    final statusImageSize = min(size.width / 2, 300.0);
    var callImageSize = min(size.width / 2, 400.0);
    var connectMyId = AppManager.myId;
    if (AppManager.settings["DELEGATORCODE"] != null) {
      connectMyId = AppManager.myId
          .replaceAll(AppManager.settings["DELEGATORCODE"] + "_", "");
    }
    var spanaSize = Size(45, 30);
    if (size.shortestSide > 500) {
      spanaSize = Size(60, 45);
    }
    if (size.width > size.height) {
      callImageSize = min(size.height * 0.7, 500.0);
    }
    const messageHeight = 128.0;//78.0　メッセージ配信　20231223
    const messageFontSize = 104.0;//64.0　メッセー文字サイズ　20231223
    var message = _infoMessage;
    if (_infoMessage.length * messageFontSize < size.width) {
      var addChars = ((size.width - (_infoMessage.length * messageFontSize)) / messageFontSize).floor();
      for (var i = 0; i < addChars; i++) {
        message += '　';
      }
    }
    final sleepMode = _isSleepMode();

    const menuButtonWidth = 230.0;//240 横幅　20241223
    const menuButtonHeight = 230.0;//80　高さ　20241223
    const menuButtonMargin = 0.0;//8.0　間隔　20241223
    const menuButtonFontSize = 48.0;//30.0　文字サイズ　20241223
    const menuButton2Width = 140.0;//240 横幅　20241223
    const menuButton2Height = 72.0;//80　高さ　20241223
    const menuButton2Margin = 0.0;//8.0　間隔　20241223
    const menuButton2FontSize = 30.0;//30.0　文字サイズ　20241223

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Material(color: Colors.white),
            if (!_talking)
              InkWell(
                onTap: () {
                  _tap();
                },
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(AppManager.roomImageName(size)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (_statusImage.isNotEmpty)
              Positioned(
                top: size.height / 2 - (statusImageSize / 2),
                left: size.width / 2 - (statusImageSize / 2),
                height: statusImageSize,
                width: statusImageSize,
                child: Image.asset(_statusImage),
              ),
            Container(
              color: Colors.black,
              child: Center(
                child: ClockWidget(),
              ),
            ),
            Positioned(
              bottom: 15,//20241223　0　メッセージのマージン
              height: messageHeight,
              width: size.width,
              child: Marquee(
                  text: message.isEmpty ? '　' : message,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 129, 146, 92),//メッセージの色
                    fontSize: messageFontSize,
                    fontWeight: FontWeight.bold,
                  )),
            ), // メッセージ
            if (!sleepMode && _imageFiles.length > _imageFileIndex && _imageFileIndex > -1) ...[
              Container(
                color: Colors.black,
              ),
              AnimatedOpacity(
                duration: Duration(seconds: 1),
                opacity: _imageOpacity,
                child: Image.network(
                  '${AppDefine.baseURL}image?path=${_imageFiles[_imageFileIndex]}',
                  width: size.width,
                  height: size.height - messageHeight,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (!sleepMode && _infoVideo.isNotEmpty && _controller != null && _controller!.value.isInitialized)
              Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 8,
              right: max(MediaQuery.of(context).padding.right, 8),
              height: iconSize,
              // right: constraints.maxWidth,
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(_isconnect
                            ? 'assets/images/led/ledG.png'
                            : 'assets/images/led/led2.png'),
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            '${_isconnect ? 'ON' : 'OFF'} LINE $connectMyId',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ), // LED
            Positioned(//一斉呼び出しボタン
              top: 80,//iconSize 20241223
              left: 8,
              right: max(MediaQuery.of(context).padding.right, 8),
              // right: constraints.maxWidth,
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              width: menuButtonWidth,
                              height: menuButtonHeight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                  const Color.fromARGB(255, 115, 176, 236),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  // _startMovie();
                                  _tap();
                                },
                                child: WidgetUtil.middleText('一斉呼出', fontSize: menuButtonFontSize, color: Colors.white,),
                              ),
                            ),
                            const SizedBox(height: menuButtonMargin,),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ), // メニューボタン
            Positioned(//設定ボタン
              top: 520,//iconSize 20241223
              left: 8,
              right: max(MediaQuery.of(context).padding.right, 8),
              // right: constraints.maxWidth,
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: menuButton2Margin,),
                            SizedBox(
                              width: menuButton2Width,
                              height: menuButton2Height,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                  const Color.fromARGB(62, 62, 62, 62),//255 115 176 236 20241223
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),//circular(5) 20241223
                                  ),
                                ),
                                onPressed: () async {
                                  _toSetting();
                                },
                                child: WidgetUtil.middleText('設定', fontSize: menuButton2FontSize, color: Color.fromARGB(255, 162, 162, 162),),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ), // メニューボタン２
            if (AppManager.allTalking)
              Container(
                color: Color.fromARGB(255, 208, 241, 255),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WidgetUtil.middleText('訪問中のため', fontSize: 48),
                    WidgetUtil.middleText('しばらくお待ちください', fontSize: 48),
                    Image.asset(
                      height: size.width / 4,
                      'assets/images/room/timeout.gif',
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  ///
  /// socket service
  ///
  @override
  void onConnect() {
    var useType = "0";
    if (AppManager.settings["DISPTYPE"] == '2') {
      useType = '1';
    }

    socketservice.delegatorLogin(useType);
  }

  @override
  void onDisConnect() {
    setState(() {
      _isconnect = false;
    });
  }

  @override
  void onAppMessage(data) {
    String message = data['message'];
    _showDebugToast("App Message:$message");
    if (message == 'from_server') {
      if (data['productName'] == '%logined') {
        //   AppManager.toast("ログイン済のアカウントです。");
        return;
      }
      setState(() {
        _isconnect = true;
      });
    }
    else if (message == 'call') {
      if (data["info"]["udid"] == null) {
        return;
      }
      final udid = data["info"]["udid"];
      _receive(udid);
    }
    else if (message == 'auto_receives') {
      _onAutoReceives();
    }
    else if (message == 'safety_check') {
      if (data["udid"] == null) {
        return;
      }
      _receiveSafetyCheck(data["udid"].toString());
    }
    else if (message == 'safety_check_end') {
      if (data["udid"] == null) {
        return;
      }
      _receiveSafetyCheckEnd(data["udid"]);
    }
    else if (message == 'call_button') {
      _onCallButton();
    }
  }

  @override
  void onMessage(data) {
    if (!_active) {
      return;
    }
    var id = data['id'];
    if (id == 'callResponse') {
      var response = (data["response"] ?? '');
      if (response != 'accepted') {
        return;
      }
      var to = (data["to"] ?? '');
      var sdp = (data["sdpOffer"] ?? '');
      print('callresponse $to');
      peer.receiveOffer(to, sdp);
    } else if (id == 'startCommunication') {
      var sdp = (data["sdpAnswer"] ?? '');
      var to = (data["to"] ?? '');
      peer.receiveAnswer(to, sdp);
    } else if (id == 'iceCandidate') {
      var from = data["from"];
      var candidate = data["candidate"];
      if (from == null || candidate == null) {
        return;
      }
      print('iceCandidate $from');
      peer.receiveIceCandidate(from, candidate);
    }
  }

  @override
  void onCallResponse(to, sdp) {
    if (!_active) {
      return;
    }
    peer.receiveOffer(to, sdp, 'sendonly');
  }

  @override
  void onStartCommunication(to, sdp) {
    if (!_active) {
      return;
    }
    peer.receiveAnswer(to, sdp);
  }

  @override
  void onMessageIceCandidate(from, candidate) {
    if (!_active) {
      return;
    }
    peer.receiveIceCandidate(from, candidate);
  }

  @override
  void onTalkMessage(data) {
    // TODO: implement onTalkMessage
  }

  void _onLocalStream(stream) {
    print('onlocal stream');
    peer.setAudioEnabled(false);
  }

  void _onAddRemoteStream(id, stream) {
    print('onremote stream $id');
  }

  void _onOffer(data) {
    print('onoffer');
    // print(data);

    final args = {
      "id": "incomingCallResponse",
      "callResponse": "accept",
      "sdpOffer": data['sdp'],
      "from": data['id']
    };
    socketservice.io.emit("message", [args]);
  }

  void _onAnswer(data) {
    print('onanswer');
    final args = {
      "id": "answerResponse",
      "callResponse": "accept",
      "sdpAnswer": data['sdp'],
      "from": data['id']
    };
    socketservice.io.emit("message", [args]);
  }

  void _onIceCandidate(id, candidate) {
    final args = {
      "id": "onIceCandidate",
      "to": id,
      "name": id,
      "sender": id,
      "candidate": candidate
    };
    socketservice.io.emit("message", [args]);
  }
}
