import 'dart:async';
import 'dart:convert';
import 'package:ami/notifiers/app_notifier.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_define.dart';
import '../../app_manager.dart';
import '../../app_router.dart';
import '../../helpers/widget_helper.dart';
import '../../notifiers/address_notifier.dart';
import '../../services/audio_service.dart';
import '../../services/peer_service.dart';
import '../../services/socket_io_service.dart';

class TalkPage extends StatefulWidget {
  @override
  _TalkPageState createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage>
with WidgetsBindingObserver, SocketIOServiceDelegate,
    SingleTickerProviderStateMixin {

  Peer peer = Peer();
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _remote2Renderer = RTCVideoRenderer();
  bool _hasRemoteVideo = false;
  bool _hasRemote2Video = false;
  bool _minimiseLocalRenderer = false;
  double _remoteMargin = 0;

  SocketIOService socketservice = SocketIOService();
  AudioService audio = AudioService();
  bool _talking = false;
  bool _video = false;
  Timer? _rusuTimer;
  bool _isNear = false;
  late StreamSubscription<dynamic> _streamSubscription;

  /// 通話中着信対応
  String _callingId = '';
  String _callingName = '';
  AnimationController? _blinkAnimationController;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    socketservice.delegate2 = this;
    peer.onStateChange = _onStateChange;
    peer.onLocalStream = _onLocalStream;
    peer.onOffer = _onOffer;
    peer.onAnswer = _onAnswer;
    peer.onAddRemoteStream = _onAddRemoteStream;
    peer.onIceCandidate = _onIceCandidate;
    _initRenderers();
    _listenSensor();

    AppManager.isMute = false;
    AppManager.isVideoMute = true;

    _blinkAnimationController = AnimationController(duration: Duration(seconds: 1), vsync: this)
      ..repeat(reverse: true);

    Future(() async {
      AppManager.setStatusBarHidden(false);
      if (AppManager.callId.isNotEmpty) {
        socketservice.io.emit("calling?", [AppManager.selectUser!.id]);
        AppManager.callId = '';
      }
      if (AppManager.acceptId.isNotEmpty) {
        socketservice.io.emit("calling?", [AppManager.selectUser!.id]);
        AppManager.acceptId = '';
        // prefs.remove('accept_id');
      }
      if (AppManager.appsettings["AUTO_RECEIVE"] == '1') {

      }
    });
  }

  @override
  void dispose() {
    print('talk dispose');
    socketservice.delegate2 = null;
    _streamSubscription.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _remote2Renderer.dispose();
    _blinkAnimationController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // print(state);
    // setState(() {
    //   _notification = state;
    // });
    if (state == AppLifecycleState.resumed) {
      print('talk resumed');
    } else if (state == AppLifecycleState.paused) {
      print('talk paused');
      context.pop();
    }
  }

  void _setAppStatus(newStatus) {
    AppManager.status = newStatus;

    print('set status -> ${newStatus}');

    bool talking = false;

    if (newStatus == AppStatus.Talk ||
        newStatus == AppStatus.Multi ||
        newStatus == AppStatus.MultiToTalk) {
      talking = true;
    }

    setState(() {
      _talking = talking;
    });
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _remote2Renderer.initialize();
  }

  Future<void> _listenSensor() async {
    FlutterError.onError = (FlutterErrorDetails details) {

    };
    _streamSubscription = ProximitySensor.events.listen((int event) {
      setState(() {
        _isNear = event > 0 ? true : false;
      });
      print('proximity sensor ${event}');
    });
  }

  void _close() {
    if (AppManager.selectUser != null) {
      final selectUserId = AppManager.selectUser!.id;
      context.read<AddressStore>().setSensor(selectUserId, '');
      // context.read<AddressStore>().setCalled(selectUserId, 0);
    }
    AppManager.selectUser = null;
    context.pop();
  }

  Future<void> _call() async {
    await audio.call();
    _setAppStatus(AppStatus.Call);
    print('call to ->${AppManager.selectUser!.id}');
    socketservice.io.emit("call", [AppManager.selectUser!.id]);

    print("call to " + AppManager.selectUser!.id);

    _rusuTimer = Timer.periodic(Duration(milliseconds: AppDefine.absenceSec1), (Timer timer) {
      _close();
    });
  }

  void _cancelCall() {
    socketservice.io.emit("call_cancel", [AppManager.selectUser!.id]);
    _stopRusuTimer();
    audio.stopCall();
    _setAppStatus(AppStatus.None);
    _close();
  }

  void _response() {
    audio.stopRingtone();
    context.read<AddressStore>().setCalled(AppManager.selectUser!.id, 0);
    _setAppStatus(AppStatus.Response);
    AppManager.talkId1 = AppManager.selectUser!.id;
    peer.invite(AppManager.selectUser!.id, 'video', true); // => _onOffer
  }

  void _rejectCall() {
    socketservice.io.emit("call_reject", [AppManager.selectUser!.id]);
    context.read<AddressStore>().setCall(AppManager.selectUser!.id, 0);
    _setAppStatus(AppStatus.None);
    audio.stopRingtone();
    _close();
  }

  void _stopRusuTimer() {
    if (_rusuTimer != null) {
      _rusuTimer!.cancel();
    }
  }

  void _notConnect(String connectStatus) {
    _setAppStatus(AppStatus.None);
    if (connectStatus == '1') {
      AppManager.toast("呼び出し先が不在です", bgColor: Colors.blue);
    } else {
      AppManager.toast("通話中です", bgColor: Colors.blue);
    }
    _stopRusuTimer();
    audio.stopCall();
    _close();
  }

  void _startTalk() {
    _stopRusuTimer();
    context.read<AddressStore>().setCall(AppManager.selectUser!.id, 0);
    context.read<AddressStore>().setCalled(AppManager.selectUser!.id, 0);
    _setAppStatus(AppStatus.Talk);
    audio.stopCall();

    Future.delayed(Duration(seconds: 1), () {
      var sendData = {
        "id2": "talk_info",
        "user_name": AppManager.settings['MCSCLINICNAME'],
        'name': AppManager.settings['MCSNAME']
      };
      print(sendData);
      socketservice.io.emit("talk", [sendData]);
    });
  }

  void _hangup() {
    print('hangup ${_talking}');
    if (AppManager.holdId == AppManager.selectUser!.id) {
      // 保留中は通話終了
      AppManager.holdId = '';
      socketservice.io.emit("hold_end", [AppManager.selectUser!.id]);
    } else if (AppManager.holdedId == AppManager.selectUser!.id) {
      // 保留中は通話終了
      AppManager.holdedId = '';
      socketservice.io.emit("holded_end", [AppManager.selectUser!.id]);
    } else if (_talking) {
      // 通話中は通話終了
      socketservice.io.emit("hangup", []);
    }

    AppManager.talkId1 = '';
    AppManager.talkId2 = '';

    var newStatus = AppStatus.None;
    if (AppManager.holdId.isNotEmpty) {
      newStatus = AppStatus.Hold;
    }
    _setAppStatus(newStatus);

    _endTalk();
  }

  void _receiveCallCancel(String from) {
    AppStatus newStatus = AppStatus.None;
    if (from == AppManager.selectUser!.id) {
      context.read<AddressStore>().setCall(from, 0);
      // context.read<AddressStore>().setCalled(from, 1);
      _setAppStatus(AppStatus.None);
      audio.stopRingtone();
      _close();
    }

  }

  void _receiveHangup(String from) {
    print("****************     receiveHangup: $from   talkId1 = ${AppManager.talkId1}   ********************************");
    AppStatus newStatus = AppStatus.None;

    if (AppManager.holdId == from) {
      // 保留相手から切断
      AppManager.holdId = "";
      if (AppManager.selectUser!.id == from) {
        // 保留相手選択中は通話終了処理
        _setAppStatus(newStatus);
        _endTalk();
        return;
      }
      if (AppManager.talkId1.isEmpty) {
        // 通話相手なし
      }
    } else if (AppManager.holdedId == from) {
      // 保留された相手から切断
      AppManager.holdedId = "";
      AppManager.talkId1 = "";
      _endTalk();
      _setAppStatus(newStatus);
      return;
    } else if (AppManager.talkId1 == from) {
      if (AppManager.talkId2.isNotEmpty) {
        // 三者通話中
      } else {
        // 通話終了
        AppManager.talkId1 = "";
        if (AppManager.holdId.isNotEmpty) {
          newStatus = AppStatus.Hold;
        }
        _setAppStatus(newStatus);
        _endTalk();
        return;
      }
    } else if (AppManager.talkId2 == from) {
      // 三者通話中
    }
  }

  Future<void> _endTalk() async {
    setState(() {
      _hasRemoteVideo = false;
      _hasRemote2Video = false;
    });
    // recording 終了

    // await FlutterCallkitIncoming.endAllCalls();
    peer.close();
    _close();
  }

  /// *******************************************************************************************
  /// other buttons
  /// *******************************************************************************************
  void _changeCamera() {
    peer.switchCamera();
  }

  Widget buttonsWidget() {
    const buttonSize = 60.0;
    const fontSize = 16.0;
    if (AppManager.status == AppStatus.Call) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              ClipOval(
                child: Material(
                  color: Colors.red, // Button color
                  child: InkWell(
                    onTap: () {
                      _cancelCall();
                    },
                    child: const SizedBox(width: buttonSize, height: buttonSize, child: Icon(Icons.close, color: Colors.white,)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: EdgeInsets.only(left: 20),
          child: Column(
            children: [
              ClipOval(
                child: Material(
                  color: Colors.red, // Button color
                  child: InkWell(
                    onTap: () {
                      _rejectCall();
                    },
                    child: const SizedBox(width: buttonSize, height: buttonSize, child: Icon(Icons.call_end, color: Colors.white,)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('拒否', style: TextStyle(fontSize: fontSize, color: Color.fromARGB(200, 255, 255, 255),),)
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.only(right: 20),
          child: Column(
            children: [
              ClipOval(
                child: Material(
                  color: Colors.green, // Button color
                  child: InkWell(
                    onTap: () {
                      socketservice.io.emit("calling?", [AppManager.selectUser!.id]);
                    },
                    child: const SizedBox(width: buttonSize, height: buttonSize, child: Icon(Icons.call, color: Colors.white,)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('応答', style: TextStyle(fontSize: fontSize, color: Colors.white,),)
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var address = AppManager.selectUser;
    if (address == null || AppManager.status == AppStatus.None || _isNear || AppManager.status == AppStatus.Response) {
      return Container(color: Colors.black);
    }
    if (!_talking) {
      return _callWidget();
    }
    return _talkWidget();
    final Size size = MediaQuery.of(context).size;
    double verticalPadding = 150.0;
    double verticalPadding2 = 50.0;
    if (size.height < 700) {
      verticalPadding = 80.0;
      verticalPadding2 = 10.0;
    }
    double paddingX = 50;
    if (size.width > 700) {
      paddingX = 200;
    }

    final addressPhoto = address!.photoBytes();
    Widget imageWidget = addressPhoto.isEmpty ? Image.asset(
      'assets/images/talk/avater.png',
      fit: BoxFit.cover,
      gaplessPlayback: true,
      width: 150,
    ): ClipRRect(
      borderRadius: BorderRadius.circular(60.0),
      child: Image.memory(
        addressPhoto,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: 120,
      ),
    );

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 56),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${address.name} 様',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('こぶし園しなの',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  imageWidget,
                ],
              ),
              buttonsWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _callWidget() {
    var address = AppManager.selectUser!;

    final addressPhoto = address.photoBytes();
    Widget imageWidget = addressPhoto.isEmpty ? Image.asset(
      'assets/images/talk/avater.png',
      fit: BoxFit.cover,
      gaplessPlayback: true,
      width: 150,
    ): ClipRRect(
      borderRadius: BorderRadius.circular(60.0),
      child: Image.memory(
        addressPhoto,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: 120,
      ),
    );

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 37, 84, 241),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 150),
                  Text('${address.name} 様',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(address.userName,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              buttonsWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _talkWidget() {
    var address = AppManager.selectUser!;
    final Size size = MediaQuery.of(context).size;
    var button1Width = size.width / 4;
    if (button1Width > 120) {
      button1Width = 120;
    }
    if (size.width < 500 && button1Width > 90) {
      button1Width = 90;
    }
    var button1Height = button1Width / 335 * 182;
    var button2Width = button1Height / 182 * 228;
    var button3Height = button2Width / 239 * 130;
    var _callendIsEnabled = true;

    const smallButtonSize = 32.0;
    var topOffset = 10.0;
    var leftOffset = 12.0;

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 232),
      body: SafeArea(
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WidgetUtil.basicText('${address.name} 様', fontSize: 24.0),
                  const SizedBox(height: 10.0),
                  WidgetUtil.basicText(address.userName, fontSize: 24.0),
                ],
              ),
            ),
            if (_video)
              ... [
                Positioned(
                  top: 0,
                  left: 0,
                  height: AppManager.status == AppStatus.Multi
                      ? size.height / 2
                      : size.height,
                  width: size.width - _remoteMargin,
                  child: RTCVideoView(_remoteRenderer, mirror: false, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,),
                ),
                Positioned(
                  bottom: 20,
                  right: _minimiseLocalRenderer ? 20 : 0,
                  height: _minimiseLocalRenderer ? 28 : size.height / 4,
                  width: _minimiseLocalRenderer ? 28 : size.height / 4 / 3 * 2,
                  child: GestureDetector(
                    onTap: () {
                      if (_minimiseLocalRenderer) {
                        setState(() {
                          _minimiseLocalRenderer = false;
                        });
                      }
                    },
                    onVerticalDragUpdate: (DragUpdateDetails details) {

                    },
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null) {
                        print(details.primaryVelocity!);
                        if (details.primaryVelocity! >= 0 && !_minimiseLocalRenderer) {
                          // 下向き
                          setState(() {
                            _minimiseLocalRenderer = true;
                          });
                        } else if (details.primaryVelocity! < 0 && _minimiseLocalRenderer) {
                          // 上向き
                          setState(() {
                            _minimiseLocalRenderer = false;
                          });
                        }
                      }
                    },
                    child: _minimiseLocalRenderer ?
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                      ),
                      height: 28,
                      width: 28,
                    ) : RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
                Positioned(
                  top: topOffset,
                  left: leftOffset,
                  width: size.width - (leftOffset * 2),
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _changeCamera();
                          },
                          child: SizedBox(
                            width: smallButtonSize,
                            height: smallButtonSize,
                            child: Image.asset("assets/images/talk/btn-change_my_camera.png"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            Positioned(
              bottom: 10,
              child: Row(
                children: [
                  GestureDetector(
                    child: Image.asset(
                      'assets/images/talk/btn-cam-off.png',
                      width: button1Width,
                      height: button1Height,
                    ),
                    onTap: () {
                      setState(() {
                        _video = !_video;
                        peer.setVideoEnabled(_video);
                      });

                      var sendData = {
                        "id2": "toggle_video",
                        "val": _video ? '1' : '0'
                      };
                      socketservice.io.emit("talk", [sendData]);
                    },
                  ),
                  Opacity(
                    opacity: _callendIsEnabled ? 1.0 : 0.5,
                    child: GestureDetector(
                      child: Image.asset(
                        'assets/images/talk/btn-callend.png',
                        width: button1Width,
                        height: button1Height,
                      ),
                      onTap: () {
                        _hangup();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_callingId.isNotEmpty)
              Positioned(
                top: 40,
                right: 4,
                width: 120,
                height: 80,
                child: FadeTransition(
                  opacity: _blinkAnimationController!,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.red,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '着信中',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _callingId,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _callingName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// *******************************************************************************************
  /// socket io
  /// *******************************************************************************************
  @override
  void onAppMessage(data) {
    String message = data['message'];
    print('talk app message $message');
    if (!mounted || AppManager.selectUser == null) {
      return;
    }
    if (message == '') {

    }
    else if (message == 'status_change') {
      print('select user status ${data["info"]["STATUS"]}');
      if (data["info"]["MYID"] != null && data["info"]["MYID"] == AppManager.selectUser!.id) {
        if (data["info"]["STATUS"] == '-1') {
          if (AppManager.status == AppStatus.Call) {
            _cancelCall();
          } else if (AppManager.status == AppStatus.Receive) {
            _receiveCallCancel(AppManager.selectUser!.id);
          } else if (AppManager.status == AppStatus.Talk) {
            _receiveHangup(AppManager.selectUser!.id);
          }
        } else if (data["info"]["STATUS"] == '2') {
          if (AppManager.talkId1 != AppManager.selectUser!.id) {
            context.read<AddressStore>().setCall(AppManager.selectUser!.id, 0);
            _setAppStatus(AppStatus.None);
            audio.stopRingtone();
            _close();
          }
        }
      }
    }
    else if (message == 'call_cancel') {
      if (data["udid"] == null) {
        return;
      }
      if (_callingId == data["udid"]) {
        setState(() {
          _callingId = '';
          _callingName = '';
        });
      }
      _receiveCallCancel(data["udid"]);
    }
    else if (message == 'not_connect') {
      if (data["info"] == null) {
        return;
      }
      _notConnect(data["info"]);
    }
    else if (message == 'talk_end') {
      if (data["udid"] == null) {
        return;
      }
      _receiveHangup(data["udid"]);
    }
    else if (message == 'call_talking') {
      if (data["info"]["udid"] == null) {
        return;
      }
      if (AppManager.status == AppStatus.Talk) {
        var address = context.read<AddressStore>().find(data["info"]["udid"]);
        if (address != null) {
          setState(() {
            _callingId = address.id;
            _callingName = address.name;
          });
        }
      }
    }
    else if (message == 'calling') {
      if (data['calling'].toString() == '1') {
        print('calling to response');
        _response();
      } else {
        print('calling to call');
        audio.stopRingtone();
        _call();
      }
    }
  }

  @override
  void onMessage(data) {
    var id = data['id'];
  }

  @override
  void onCallResponse(to, sdp) {
    if (to != AppManager.safetyCheckId) {
      AppManager.talkId1 = AppManager.selectUser!.id;
    }
    peer.receiveOffer(to, sdp);
  }

  @override
  void onStartCommunication(to, sdp) {
    peer.receiveAnswer(to, sdp);

    if (AppManager.status != AppStatus.MultiToTalk) {
      socketservice.io.emit("call_accept", [to]);
    }
    _startTalk();
  }

  @override
  void onMessageIceCandidate(from, candidate) {
    print('iceCandidate $from');
    peer.receiveIceCandidate(from, candidate);
  }

  @override
  void onTalkMessage(data) {
    String id2 = data['id2'];
    print('talk message $id2');
  }

  @override
  void onConnect() {

  }

  @override
  void onDisConnect() {
    // TODO: implement onDisConnect
  }

  /// *******************************************************************************************
  /// peer
  /// *******************************************************************************************
  void _onStateChange(id, state) {

  }

  void _onLocalStream(stream) {
    print('onlocal stream');
    _setLocalStream(stream);
  }

  Future<void> _setLocalStream(stream) async {
    // if (_localRenderer == null) {
    //   _localRenderer = RTCVideoRenderer();
    //   await _localRenderer!.initialize();
    // }
    _localRenderer.srcObject = stream;
  }

  void _onAddRemoteStream(id, stream) {
    print('onremote stream $id');
    if (id == AppManager.talkId1) {
      _setRemoteStream(stream);
    } else if (id == AppManager.talkId2) {
      _setRemote2Stream(stream);
    } else if (id == AppManager.safetyCheckId) {
      _setRemoteStream(stream);
    }
  }

  Future<void> _setRemoteStream(stream) async {
    // if (_remoteRenderer == null) {
    //   _remoteRenderer = RTCVideoRenderer();
    //   await _remoteRenderer!.initialize();
    // }
    _remoteRenderer.srcObject = stream;

    setState(() {
      _hasRemoteVideo = true;
    });
  }

  Future<void> _setRemote2Stream(stream) async {
    // if (_remote2Renderer == null) {
    //   _remote2Renderer = RTCVideoRenderer();
    //   await _remote2Renderer!.initialize();
    // }
    _remote2Renderer.srcObject = stream;

    setState(() {
      _hasRemote2Video = true;
    });
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
    if (data['id'] != AppManager.safetyCheckId) {
      _startTalk();
    }
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