import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ami/app_router.dart';
import 'package:ami/helpers/staff_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../app_define.dart';
import '../app_manager.dart';
import '../helpers/widget_helper.dart';
import '../models/address_model.dart';
import '../notifiers/address_notifier.dart';
import '../notifiers/app_notifier.dart';
import '../services/audio_service.dart';
import '../services/sensor_service.dart';
import '../services/socket_io_service.dart';
import '../widgets/biosilver_popup_widget.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        WidgetsBindingObserver,
        SocketIOServiceDelegate,
        SensorServiceDelegate {
  bool _ready = false;
  late final Uuid _uuid;
  String _version = '1.0';
  SocketIOService socketservice = SocketIOService();
  AudioService audio = AudioService();
  SensorService sensorService = SensorService();
  bool _isconnect = false;
  List<Address> addressList = [];
  List<dynamic> _callStatuses = [];
  Map<String, Map<String, dynamic>> _spo2Result = {};
  bool _islist = false;
  bool _isActive = false;
  bool _loading = false;
  bool _showHistory = false;
  bool _showCallHistory = false;
  bool _showCalledHistory = false;
  bool _hasMoreTalkLogs = false;
  int _historyPage = 1;
  List<dynamic> _talkLogs = [];
  List<dynamic> _callLogs = [];
  List<dynamic> _calledList = [];
  Widget? biosilverPopup;
  Timer? _buttonCallTimer;
  Timer? _webLiveImageTimer;
  Timer? _showSpo2Timer;
  String _debug = 'dbug中\n';

  @override
  void initState() {
    super.initState();
    print('[DEBUG PRINT] home initState');

    WidgetsBinding.instance.addObserver(this);

    _uuid = const Uuid();
    socketservice.delegate = this;
    sensorService.delegate = this;
    AppManager.setStatusBarHidden(true);

    Future(() async {
      var load = await AppManager.loadSetting();
      if (!load) {
        _logout();
      }

      _requestPermission();
      _loadAddress();
      socketservice.startConnectTimer();
      _startButtonCallTimer();

      if (socketservice.connected) {
        _isconnect = true;
        Future(() {
          socketservice.io
              .emit("clients_status", [AppManager.settings['addressGroup']]);
        });
      }

      _version = await AppManager.appVersion();

      if (AppManager.appsettings['SENSOR1'] == '1' ||
          AppManager.appsettings['SENSOR2'] == '1' ||
          AppManager.appsettings['SENSOR3'] == '1' ||
          AppManager.appsettings['SENSOR5'] == '1') {
        sensorService.startWatch();
      }

      if (AppDefine.useWebLiveImage) {
        _startWebLiveImageTimer();
      }
      if (AppDefine.showSpo2) {
        _startShowSpo2Timer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('resumed');
      if (AppManager.appsettings['SENSOR1'] == '1' ||
          AppManager.appsettings['SENSOR2'] == '1' ||
          AppManager.appsettings['SENSOR3'] == '1') {
        sensorService.startWatch();
      }

      socketservice.reconnect = true;
      socketservice.startConnectTimer();
      _startButtonCallTimer();
      if (AppDefine.useWebLiveImage) {
        _startWebLiveImageTimer();
      }
      if (AppDefine.showSpo2) {
        _startShowSpo2Timer();
      }
    } else if (state == AppLifecycleState.paused) {
      _setPausedTime();
      _stopTimers();
      audio.stopRingtone();
      sensorService.stopWatch();

      socketservice.reconnect = false;
      socketservice.stopTimer();
      socketservice.disconnect();
      print('paused');
      setState(() {
        _ready = false;
        _isconnect = false;
      });
    }
  }

  @override
  void dispose() {
    print('staff dispose');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setPausedTime() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('paused_time',
        WidgetUtil.dateFormat(DateTime.now(), 'yyyy-MM-dd H:m:ss'));
  }

  Future<void> _checkAccept() async {
    final prefs = await SharedPreferences.getInstance();
    final incomingCallData = prefs.getString('incoming_call_data');

    if (incomingCallData != null) {
      prefs.remove('incoming_call_data');
      print('Processing incoming call: $incomingCallData');
    }

    setState(() {
      _ready = true;
    });

    socketservice.io
        .emit("clients_status", [AppManager.settings['addressGroup']]);
    _checkCalled();
  }

  Future<void> _checkTalkHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final pausedTime = prefs.getString('paused_time');
    if (pausedTime == null) {
      return;
    }

    _talkLogs.clear();
    await _getData(AppManager.delegatorCode, start: pausedTime);
    if (_talkLogs.isEmpty) {
      return;
    }
    setState(() {
      _showHistory = true;
      _showCalledHistory = false;
      _showCallHistory = false;
      _historyPage = 1;
    });
  }

  Future<dynamic> initCurrentCall() async {
    return null;
  }

  Future<void> _logout() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool('login', false);
  }

  Future<void> initPlatformState() async {
    if (!mounted) return;
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
    } else if (Platform.isIOS) {}
  }

  Future<Map<String, dynamic>> _getCalledData() async {
    setState(() {
      _loading = true;
    });

    final url = AppManager.settings['server'] + '/called';
    print(url);

    final dio = Dio();
    var data = await dio
        .get(
      url,
    )
        .then((response) {
      print(response.data);
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    setState(() {
      _loading = false;
    });

    if (data != null) {
      return data['LIST'];
    }

    return {};
  }

  Future<void> _checkCalled() async {
    var data = await _getCalledData();
    var isCalled = false;
    data.forEach((String targetId, dt) {
      final index = context.read<AddressStore>().findAddress(targetId);
      if (index >= 0) {
        isCalled = true;
      }
    });
    if (isCalled) {
      _showCalled();
      audio.ringtone();
      return;
    }

    _checkTalkHistory();
  }

  Future<void> _showCalled() async {
    var data = await _getCalledData();

    data.forEach((String targetId, dt) {
      context.read<AddressStore>().setCalledTime(targetId, dt);
    });

    setState(() {
      _showHistory = false;
      _showCallHistory = false;
      _showCalledHistory = true;
    });
  }

  void _loadAddress() {
    SharedPreferences.getInstance().then((prefs) {
      String? addressString = prefs.getString('address');
      if (addressString != null) {
        var addressJson = json.decode(addressString);
        context.read<AddressStore>().setAddressList(addressJson);
      }
    });
  }

  void _stopTimers() {
    _stopButtonCallTimer();
    _stopWebLiveImageTimer();
    _stopShowSpo2Timer();
  }

  void _stopShowSpo2Timer() {
    print('called stop show spo2 timer');
    if (_showSpo2Timer != null) {
      print('stop show spo2 timer');
      _showSpo2Timer!.cancel();
    }
  }

  void _startShowSpo2Timer() {
    _stopShowSpo2Timer();

    _showSpo2Timer = Timer.periodic(const Duration(seconds: 10), (Timer timer) {
      _checkShowSpo2();
    });
  }

  Future<void> _checkShowSpo2() async {
    if (!mounted) {
      return;
    }
    if (AppManager.status != AppStatus.None) {
      return;
    }
    _spo2Result.clear();
    var addressStore = context.read<AddressStore>();
    var isManagerList = AppManager.isManager && AppManager.selectCode.isEmpty;
    var list =
        isManagerList ? addressStore.managerList() : addressStore.staffList();
    var ids = list.map((data) => data.id.toString()).toList();
    final postData = {
      'isManager':
          AppManager.isManager && AppManager.selectCode.isEmpty ? '1' : '0',
      'ids': jsonEncode(ids)
    };

    final dio = Dio();
    var data = await dio
        .post(
      '${AppDefine.baseURL}app/spo2_value',
      data: FormData.fromMap(postData),
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      }),
    )
        .then((response) {
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    if (data == null) {
      return;
    }

    print(ids);
    print(data);
    var isError = false;
    ids.forEach((udid) {
      if (data[udid] != null) {
        print(udid);
        _spo2Result[udid] = data[udid];
        if (data[udid]['err1'].toString().isNotEmpty) {
          isError = true;
        }
        if (data[udid]['err2'].toString().isNotEmpty) {
          isError = true;
        }
        addressStore.setSensor(udid, data[udid]['spo2'].toString());
      }
    });
    if (isError) {
      audio.spo2();
    }

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _stopWebLiveImageTimer() {
    print('called stop web live image timer');
    if (_webLiveImageTimer != null) {
      print('stop web live image timer');
      _webLiveImageTimer!.cancel();
    }
  }

  void _startWebLiveImageTimer() {
    _stopWebLiveImageTimer();

    _webLiveImageTimer =
        Timer.periodic(const Duration(seconds: 10), (Timer timer) {
      _checkWebLiveImage();
    });
  }

  Future<void> _checkWebLiveImage() async {
    if (AppManager.status != AppStatus.None) {
      return;
    }
    if (!mounted) {
      return;
    }
    var addressStore = context.read<AddressStore>();
    var isManagerList = AppManager.isManager && AppManager.selectCode.isEmpty;
    var list =
        isManagerList ? addressStore.managerList() : addressStore.staffList();
    var ids = list.map((data) => data.id.toString()).toList();

    final dio = Dio();
    var data = await dio
        .post(
      '${AppDefine.baseURL}app/live_image',
      data: FormData.fromMap({
        'isManager':
            AppManager.isManager && AppManager.selectCode.isEmpty ? '1' : '0',
        'ids': jsonEncode(ids)
      }),
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      }),
    )
        .then((response) {
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    if (data == null) {
      return;
    }

    ids.forEach((udid) {
      if (data[udid] != null) {
        print(udid);
        var image = data[udid];
        var base64Pos = image.indexOf('base64,');
        if (base64Pos >= 0) {
          image = image.substring(base64Pos + 'base64,'.length);
        }
        var image64 = image.replaceAll("\r\n", "");
        addressStore.setLiveImage(udid, image64);
      }
    });
  }

  void _stopButtonCallTimer() {
    print('called stop button call timer');
    if (_buttonCallTimer != null) {
      print('stop button call timer');
      _buttonCallTimer!.cancel();
    }
  }

  void _startButtonCallTimer() {
    _stopButtonCallTimer();

    _buttonCallTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _checkButtonCall();
    });
  }

  Future<void> _checkButtonCall() async {
    var prefs = await SharedPreferences.getInstance();
    String? targetId = prefs.getString('bcId');

    if (!mounted) {
      return;
    }

    if (targetId != null) {
      prefs.remove('bcId');

      print('check button call: $targetId');
      var addressStore = context.read<AddressStore>();
      final index = addressStore.findAddress(targetId);
      if (index < 0) {
        print('check button call: $targetId not exist');
        return;
      }
      var address = addressStore.find(targetId)!;
      if (!AppManager.isAuthReceive(address)) {
        print('check button call: $targetId not auth');
        return;
      }
      if (address.call == 1) {
        print('check button call: $targetId is calling');
        return;
      }
      if (AppManager.status == AppStatus.Call ||
          AppManager.status == AppStatus.Talk ||
          AppManager.status == AppStatus.Multi ||
          AppManager.status == AppStatus.MultiToTalk) {
      } else {
        audio.stopRingtone();
        audio.buttonCall();
      }

      addressStore.setCalled(targetId, 1);
    }
  }

  Widget _addressCell(Address address) {
    print("addressCell ${address.id}:${address.name}");

    if (_islist) {
      return _addressListCell(address);
    }

    String liveText = '';
    Uint8List bytes = Uint8List(0);
    var imageName = 'assets/images/status/offline.png';
    if (address.call == 1) {
      imageName = 'assets/images/status/addr_call.png';
    } else if (address.called == 1) {
      imageName = 'assets/images/status/addr_called.png';
    } else if (address.supported == 1) {
      imageName = 'assets/images/status/addr_supported.png';
    } else if (address.status == 0 || address.status == 1) {
      imageName = 'assets/images/status/addr.png';
      if (address.userType == 'S') {
        imageName = 'assets/images/status/addr_staff.png';
      }
      if (address.sensors.isNotEmpty) {
        print("biosliv image");
        var sensorImage = SensorService.biosilverImageName(address.sensors);
        if (sensorImage.isNotEmpty) {
          imageName = sensorImage;
        }
      } else if (address.sensor.isNotEmpty) {
      } else if (address.photo.isNotEmpty) {
        bytes = address.photoBytes();
      }
    } else if (address.status == 2 ||
        address.status == 3 ||
        address.status == 4 ||
        address.status == 5) {
      imageName = 'assets/images/status/addr_talk.png';
    } else if (address.status == 9) {
      liveText = 'LIVE';
    } else if (address.status == -1) {
      if (address.sensors.isNotEmpty) {
        print("biosliv image");
        var sensorImage = SensorService.biosilverImageName(address.sensors);
        if (sensorImage.isNotEmpty) {
          imageName = sensorImage;
        }
      } else if (address.sensor.isNotEmpty) {}
    }

    if ((imageName == 'assets/images/status/dummy.png' ||
            imageName == 'assets/images/status/addr.png') &&
        address.liveimage.isNotEmpty) {
      bytes = base64Decode(address.liveimage);
    }

    var imageWidget = Image.asset(
      imageName,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (bytes.isNotEmpty) {
      imageWidget = Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color.fromARGB(255, 80, 80, 80),
          height: 24,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              address.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              _selectAddressConfirm(address);
            },
            child: Container(
              color: const Color.fromARGB(255, 30, 30, 30),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  if (address.status == -1)
                    Opacity(
                      opacity: 0.8,
                      child: Container(
                        color: Colors.grey,
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 2.0,
                    child: Text(
                      liveText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  if (address.unableCommunication.isNotEmpty)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      width: 40,
                      child: Image.asset(
                        'assets/images/alert1.png',
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (address.battery == 1)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      width: 40,
                      child: Image.asset(
                        'assets/images/alert2.png',
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (AppDefine.showSpo2) _spo2ValueWidget(address),
      ],
    );
  }

  Widget _spo2ValueWidget(Address address) {
    double widgetHeight = 40;
    double valueFontSize = 26.0;
    double unitFontSize = 18.0;
    double margin = 8.0;
    double baseline = 30.0;

    final Size size = MediaQuery.of(context).size;
    if (size.width > 500) {
      widgetHeight = 48;
      valueFontSize = 44;
      unitFontSize = 24;
      margin = 20;
      baseline = 44.0;
    } else if (AppManager.appsettings['DISPLAYNUM'].toString() == '5') {
      widgetHeight = 16;
      valueFontSize = 14;
      unitFontSize = 12;
      margin = 3;
      baseline = 16.0;
    }
    if (_spo2Result[address.id] == null) {
      return Container(
        color: const Color.fromARGB(255, 80, 80, 80),
        height: widgetHeight + 6,
      );
    }
    var data = _spo2Result[address.id]!;
    var isError = false;
    if (data['err1'].toString().isNotEmpty) {
      isError = true;
    }
    if (data['err2'].toString().isNotEmpty) {
      isError = true;
    }
    const spo2Color = Color.fromARGB(255, 107, 231, 252);
    const pulseColor = Color.fromARGB(255, 239, 134, 50);

    return Container(
      padding: const EdgeInsets.only(bottom: 6.0),
      color: isError
          ? const Color.fromARGB(255, 227, 53, 35)
          : const Color.fromARGB(255, 80, 80, 80),
      child: Container(
        height: widgetHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Baseline(
              baseline: baseline,
              baselineType: TextBaseline.alphabetic,
              child: Text(
                data['spo2'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w500,
                  color: isError ? Colors.white : spo2Color,
                ),
              ),
            ),
            Baseline(
              baseline: baseline,
              baselineType: TextBaseline.alphabetic,
              child: Text(
                '％',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: unitFontSize,
                  color: isError ? Colors.white : spo2Color,
                ),
              ),
            ),
            SizedBox(
              width: margin,
            ),
            Baseline(
              baseline: baseline,
              baselineType: TextBaseline.alphabetic,
              child: Text(
                data['pulse'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: valueFontSize * 0.8,
                  fontWeight: FontWeight.w500,
                  color: isError ? Colors.white : pulseColor,
                ),
              ),
            ),
            Baseline(
              baseline: baseline,
              baselineType: TextBaseline.alphabetic,
              child: Text(
                'PR',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: unitFontSize * 0.8,
                  color: isError ? Colors.white : pulseColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressListCell(Address address) {
    final Size size = MediaQuery.of(context).size;
    var textSize = 14.0;
    var textWidth = 120.0;
    var buttonHeight = 72.0;
    var buttonMinWidth = 80.0;

    if (size.width < 600) {
      textSize = 13.0;
      textWidth = 80.0;
      buttonHeight = 36.0;
      buttonMinWidth = 40.0;
    }

    var buttonWidth = buttonHeight / 3 * 4;

    var issensor1 = false;
    var issensor2 = false;
    var issensor3 = false;
    var issensor4 = false;
    if (address.userType != '5') {
      if (AppManager.appsettings['SENSOR1'] == '1') {
        issensor1 = true;
      }
      if (AppManager.appsettings['SENSOR2'] == '1') {
        issensor2 = true;
      }
      if (AppManager.appsettings['SENSOR3'] == '1') {
        issensor3 = true;
      }
      if (AppManager.appsettings['SENSOR4'] == '1') {
        issensor4 = true;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 30, 30, 30),
        border: Border(
          bottom: BorderSide(color: Color.fromARGB(255, 80, 80, 80)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: textWidth,
            child: Text(
              address.name,
              style: TextStyle(
                fontSize: textSize,
                color: Colors.white,
              ),
            ),
          ),
          Center(
            child: ButtonTheme(
              minWidth: buttonMinWidth,
              height: 30.0,
              child: ElevatedButton(
                child: Text("履歴"),
                onPressed: () async {
                  _talkHistoryButton(address);
                },
              ),
            ),
          ),
          Container(width: 5.0),
          Center(
              child: GestureDetector(
            child: Image.asset(
              'assets/images/service/sc_video.png',
              width: buttonWidth,
              height: buttonHeight,
            ),
            onTap: () {
              _selectAddressConfirm(address);
            },
          )),
          Container(width: 5.0),
          issensor2
              ? Center(
                  child: GestureDetector(
                    child: Image.asset(
                      'assets/images/service/sc_pir.png',
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    onTap: () {
                      _graphButton(address, "2");
                    },
                  ),
                )
              : Container(width: buttonWidth),
          Container(width: 5.0),
          issensor1
              ? Center(
                  child: GestureDetector(
                  child: Image.asset(
                    'assets/images/service/sc_alert_H.png',
                    width: buttonWidth,
                    height: buttonHeight,
                  ),
                  onTap: () {
                    _graphButton(address, "1");
                  },
                ))
              : Container(width: buttonWidth),
          Container(width: 5.0),
          issensor3
              ? Center(
                  child: GestureDetector(
                  child: Image.asset(
                    'assets/images/service/sc_flame.png',
                    width: buttonWidth,
                    height: buttonHeight,
                  ),
                  onTap: () {
                    _graphButton(address, "3");
                  },
                ))
              : Container(width: buttonWidth),
          issensor4
              ? Center(
                  child: GestureDetector(
                  child: Image.asset(
                    'assets/images/service/sc_co2.png',
                    width: buttonWidth,
                    height: buttonHeight,
                  ),
                  onTap: () {
                    _graphButton(address, "4");
                  },
                ))
              : Container(width: buttonWidth),
        ],
      ),
    );
  }

  Widget _managerAddressCell(Address address) {
    final Size size = MediaQuery.of(context).size;
    if (_islist) {
      return AppHelper.managerAddressListCell(size, address,
          _selectManagerAddress, _talkHistoryButton, _graphButton);
    }

    var addressStore = context.read<AddressStore>();
    var tvAddress = addressStore.find('${address.code}_TV001');
    if (AppDefine.showSpo2) {
      return AppHelper.managerAddressCell(
          address, tvAddress, _selectManagerAddress,
          spo2ValueWidget: _spo2ValueWidget(address));
    }
    return AppHelper.managerAddressCell(address, tvAddress, _selectManagerAddress);
  }

  Future<void> _selectManagerAddress(Address address) async {
    // マネージャーアドレス選択時の処理
    AppManager.selectCode = address.code;
    AppManager.selectCodeName = address.name;
    setState(() {});
  }

  Widget _callStatusPopupListItem(int index) {
    var item = _callStatuses[index];
    Address address = item['address'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          _selectAddress(address);
          setState(() {
            _callStatuses.clear();
          });
        },
        child: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: Color.fromARGB(255, 80, 80, 80), width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 10),
                width: 120,
                child: Image.asset(
                  'assets/images/status/addr_call.png',
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WidgetUtil.basicText(address.name),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setAddressStatus(udid, status) {
    if (mounted) {
      context.read<AddressStore>().setLiveImage(udid, '');
      context.read<AddressStore>().setAddressStatus(udid, status);
    }
  }

  void _talkHistoryButton(Address address) {
    var cd = AppManager.delegatorCode;
    var id1 = AppManager.myId;
    var id2 = address.id;
    var name = address.name;
    var url = AppDefine.baseURL +
        "talk_history.php?cd=$cd&id1=$id1&id2=$id2&na=$name";
    print(url);
  }

  void _openCallStatusPopup() {
    if (AppManager.appsettings['CALLSTATUSDISP'] != '1') {
      return;
    }
    _callStatuses.clear();
    var addressStore = context.read<AddressStore>();

    for (var i = 0; i < addressStore.addressList.length; i++) {
      var address = addressStore.addressList[i];
      if (address.sensors.isNotEmpty) {
        var sensorImage = SensorService.biosilverImageName(address.sensors);
        if (sensorImage == 'sensor_alert_spo2.png') {
          _callStatuses.add({'address': address, 'status': 'spo2'});
          continue;
        }
      }
      if (address.call == 1) {
        _callStatuses.add({'address': address, 'status': 'call'});
      }
    }
    setState(() {});
  }

  Future<void> _graphButton(Address address, String sensorType) async {}

  Future<void> _biosilverOnClose() async {
    print('_biosilverOnClose, ' + AppManager.selectUser!.id);
    var addressStore = context.read<AddressStore>();
    addressStore.setSensors(AppManager.selectUser!.id, []);
    sensorService.biosilverAlerts.remove(AppManager.selectUser!.id);
    sensorService.resetBiosilver(AppManager.selectUser!.id);

    AppManager.selectUser = null;
    biosilverPopup = null;
    setState(() {});
  }

  Future<void> _selectAddressConfirm(Address address) async {
    final message = address.name + 'に発信しますか？';
    if (AppDefine.elanApp) {
      final type = await _showSelectAddressConfirmDialog(context, message);
      final iType = type ?? 0;
      if (iType == 1) {
        AppManager.callId = address.id;
        _selectAddress(address);
      } else if (iType == 2) {
        AppManager.safetyCheckId = address.id;
        _selectAddress(address);
      }
      return;
    }
    bool call = await WidgetUtil.showSimpleConfirmDialog(context, message);
    if (call) {
      AppManager.callId = address.id;
      _selectAddress(address);
    }
  }

  Future<int?> _showSelectAddressConfirmDialog(
      BuildContext context, String message,
      {String title = '確認'}) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            SimpleDialogOption(
              child: const Text(
                'はい',
                style: TextStyle(fontSize: 13),
              ),
              onPressed: () {
                Navigator.of(context).pop(1);
              },
            ),
            SimpleDialogOption(
              child: const Text(
                'いいえ',
                style: TextStyle(fontSize: 13),
              ),
              onPressed: () {
                Navigator.of(context).pop(0);
              },
            ),
            SimpleDialogOption(
              child: const Text(
                '見守り',
                style: TextStyle(fontSize: 13),
              ),
              onPressed: () {
                Navigator.of(context).pop(2);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectAddress(Address address) async {
    var test = 1;
    if (test == 3) {
      await audio.call();
      return;
    }
    if (test == 1) {
      setState(() {
        _ready = false;
      });
      AppManager.selectUser = address;
      print(AppManager.safetyCheckId);
      await context.push(AppRoute.talkPage);

      if (address.userType != 'S') {
        var data = await _getCalledData();
        if (data.keys.length > 0) {
          _showCalled();
        } else {
          _showTalkLog(code: address.code);
        }
      }

      setState(() {
        _ready = true;
      });
      if (!socketservice.isConnect()) {
        return;
      }
      socketservice.io
          .emit("clients_status", [AppManager.settings['addressGroup']]);
      return;
    }
    print(address.id);
    AppManager.selectUser = address;
    audio.stopButtonCall();
    if (AppDefine.showSpo2) {
      audio.stopSpo2();
    }

    if (address.sensors.isNotEmpty) {
      setState(() {
        biosilverPopup = BiosilverPopupWidget(
          udid: address.id,
          alerts: address.sensors,
          onClose: () => {_biosilverOnClose()},
        );
      });
      return;
    }

    if (address.status == 9) {
      _isActive = false;
      _isActive = true;
      return;
    }

    sensorService.clearAlert(address.id);
    if (mounted) {
      context.read<AddressStore>().setSensor(address.id, '');
      context.read<AddressStore>().setCalled(address.id, 0);
    }
  }

  void _disconnect() {
    socketservice.stopTimer();
    socketservice.reconnect = false;
    socketservice.delegate = null;
    socketservice.disconnect();
    setState(() {
      _isconnect = false;
    });
  }

  Future<void> _toSetting() async {
    _stopTimers();
    _disconnect();
    context.read<AddressStore>().clear();
    setState(() {
      _ready = false;
      _showHistory = false;
      _showCallHistory = false;
      _showCalledHistory = false;
    });
    await context.push(AppRoute.settingPage);
    print('from setting');

    _loadAddress();
    socketservice.reconnect = true;
    socketservice.delegate = this;
    socketservice.startConnectTimer();
    if (AppDefine.useWebLiveImage) {
      _startWebLiveImageTimer();
    }
  }

  Future<void> _checkFcm() async {
    var prefs = await SharedPreferences.getInstance();
    String? targetId = prefs.getString('fmId');

    if (targetId != null) {
      prefs.remove('fmId');
      socketservice.io.emit("call?", [targetId]);
    }
  }

  Future<void> _called(udid) async {
    context.read<AddressStore>().setCall(udid, 1);
    var address = context.read<AddressStore>().find(udid)!;
    if (AppManager.status == AppStatus.Call ||
        AppManager.status == AppStatus.Talk ||
        AppManager.status == AppStatus.Multi ||
        AppManager.status == AppStatus.MultiToTalk) {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('accept_id');
    } else {
      if (AppManager.selectUser == null) {
        AppManager.status = AppStatus.Receive;
        _selectAddress(address);
      }
      return;
      if (AppManager.appsettings["AUTO_RECEIVE"] == '1') {
        if (AppManager.selectUser == null) {
          AppManager.autoReceiveId = address.id;
          _selectAddress(address);
        }
        return;
      }
      audio.ringtone();
    }
    _openCallStatusPopup();
  }

  Future<void> _getCallLog(String code) async {
    setState(() {
      _loading = true;
    });

    final dio = Dio();
    var url = '${AppDefine.baseURL}app/call_history';

    var data = await dio
        .post(
      url,
      data: FormData.fromMap({
        'master_id': AppManager.settings['MCSGROUPCODE'],
        'code': code,
        'token': AppDefine.getDelegatorToken(),
        'page': _historyPage.toString()
      }),
      options: Options(
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
      ),
    )
        .then((response) {
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    setState(() {
      _loading = false;
    });

    if (data == null) {
      return;
    }

    print(data);

    _callLogs = data['logs'];
  }

  void _showCallLog() {
    _callLogs.clear();
    _showHistory = false;
    _showCalledHistory = false;
    _showCallHistory = true;
    _historyPage = 1;
    var code =
        AppManager.isManager ? AppManager.selectCode : AppManager.delegatorCode;
    _getCallLog(code);
  }

  Future<void> _getData(String code, {String? start}) async {
    setState(() {
      _loading = true;
    });

    final dio = Dio();
    var url = '${AppDefine.baseURL}app/talk_history2';
    var id1 = AppManager.myId;
    var formData = {
      'master_id': AppManager.settings['MCSGROUPCODE'],
      'token': AppDefine.getDelegatorToken(),
      'page': _historyPage.toString()
    };
    if (start != null) {
      formData['start'] = start;
    }

    var data = await dio
        .post(
      url,
      data: FormData.fromMap(formData),
      options: Options(
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
      ),
    )
        .then((response) {
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    setState(() {
      _loading = false;
    });

    if (data == null) {
      return;
    }

    print(data);

    _talkLogs = data['logs'];
  }

  void _showTalkLog({String? code}) {
    _talkLogs.clear();
    _showHistory = true;
    _showCalledHistory = false;
    _showCallHistory = false;
    _historyPage = 1;

    code ??=
        AppManager.isManager ? AppManager.selectCode : AppManager.delegatorCode;

    _getData(code);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready && false) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (context.watch<AppStore>().selectCode.isNotEmpty) {}
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarBrightness: Brightness.dark,
    ));
    const iconSize = 50.0;
    var connectMyId = AppManager.myId;
    if (AppManager.settings["DELEGATORCODE"] != null) {
      connectMyId = AppManager.myId
          .replaceAll(AppManager.settings["DELEGATORCODE"] + "_", "");
    }
    var callStatusBoxMaxHeight = MediaQuery.of(context).size.height - 80;

    PreferredSizeWidget? appBar = null;
    if (AppManager.selectCode.isNotEmpty) {
      appBar = WidgetUtil.appBar(AppManager.selectCodeName,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
              onPressed: () {
                setState(() {
                  AppManager.selectCode = '';
                  AppManager.selectCodeName = '';
                });
              },
              icon: Icon(Icons.close)));
    }
    if (_showHistory || _showCalledHistory || _showCallHistory) {
      appBar = WidgetUtil.appBar(
          _showCalledHistory ? '着信履歴' : (_showHistory ? '通話履歴' : 'コール履歴'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          leading: IconButton(
              onPressed: () {
                setState(() {
                  _showHistory = false;
                  _showCalledHistory = false;
                  _showCallHistory = false;
                });
                Future.delayed(const Duration(milliseconds: 200), () {
                  socketservice.io.emit(
                      "clients_status", [AppManager.settings['addressGroup']]);
                });
              },
              icon: Icon(Icons.close)));
    }

    return Scaffold(
      backgroundColor: _showHistory || _showCalledHistory || _showCallHistory
          ? Colors.white
          : Colors.black,
      appBar: appBar,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          var spanaSize = Size(51, 36);
          const gridPadding = 4.0;
          var gridSpacing = 10.0;
          var cols = int.parse(AppManager.appsettings['DISPLAYNUM']);
          if (cols != 2 && cols != 3 && cols != 5) {
            cols = 3;
          }
          var maxWidth = constraints.maxWidth;
          if (maxWidth > 500) {
            spanaSize = Size(60, 45);
          }
          var colWidth =
              (maxWidth - (gridSpacing * (cols - 1) + gridPadding * 2)) / cols;
          var colHeight = (colWidth / 3 * 2);
          if (AppDefine.showSpo2) {
            colHeight += 40;
          }
          colHeight += 20;

          if (_islist) {
            cols = 1;
            colWidth = maxWidth;
            colHeight = 50;
            gridSpacing = 0.0;
            if (maxWidth > 500) {
              colHeight = 80;
            }
          }

          var gridRatio = colWidth / colHeight;
          var isManagerList =
              AppManager.isManager && AppManager.selectCode.isEmpty;

          return Stack(
            fit: StackFit.expand,
            children: [
              !_ready
                  ? Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.only(bottom: iconSize),
                      child: Consumer<AddressStore>(
                        builder: (context, addressStore, _) {
                          if (_showCalledHistory) {
                            final calledList = addressStore.calledList();

                            return ListView.builder(
                              itemCount: calledList.length,
                              itemBuilder: (context, index) {
                                if (index < calledList.length) {
                                  final udid = calledList[index].id;
                                  var address = calledList[index];
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          WidgetUtil.dateFormat(
                                                              address
                                                                  .calledTime,
                                                              'M/d H:m')),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      WidgetUtil.middleText(''),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          address.name),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      WidgetUtil.middleText(
                                                          address.userName),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 60,
                                              child: GestureDetector(
                                                onTap: () {
                                                  _selectAddressConfirm(
                                                      address);
                                                },
                                                child: Image.asset(
                                                  'assets/images/status/addr_called.png',
                                                  width: 60,
                                                  height: 40,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        height: 2,
                                      ),
                                    ],
                                  );
                                }
                                return SizedBox();
                              },
                            );
                          }

                          if (_showHistory) {
                            return ListView.builder(
                              itemCount: _talkLogs.length,
                              itemBuilder: (context, index) {
                                if (index < _talkLogs.length) {
                                  final udid = _talkLogs[index]['id'];
                                  var address =
                                      context.read<AddressStore>().find(udid);
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4),
                                        color: WidgetUtil.colorFromHex(
                                            _talkLogs[index]['color']),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          _talkLogs[index]
                                                              ['start'],
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      WidgetUtil.middleText(
                                                          _talkLogs[index]
                                                              ['duration'],
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          _talkLogs[index]
                                                              ['user_name'],
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      WidgetUtil.middleText(
                                                          _talkLogs[index]
                                                              ['office_name'],
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          _talkLogs[index]
                                                              ['staff_name'],
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 30,
                                              child: address == null
                                                  ? Container()
                                                  : GestureDetector(
                                                      onTap: () {
                                                        _selectAddressConfirm(
                                                            address);
                                                      },
                                                      child: Image.asset(
                                                        'assets/images/bottom_navi/phone3.png',
                                                        width: 40,
                                                        height: 40,
                                                      ),
                                                    ),
                                            )
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        height: 2,
                                      ),
                                    ],
                                  );
                                }
                                return SizedBox();
                              },
                            );
                          }

                          if (_showCallHistory) {
                            return ListView.builder(
                              itemCount: _callLogs.length,
                              itemBuilder: (context, index) {
                                if (index < _callLogs.length) {
                                  final udid = _callLogs[index]['id'];
                                  var address =
                                      context.read<AddressStore>().find(udid);
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          _callLogs[index]
                                                              ['start'],
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      WidgetUtil.middleText(''),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      WidgetUtil.middleText(
                                                          address == null
                                                              ? _callLogs[index]
                                                                  ['name']
                                                              : address.name,
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      const SizedBox(
                                                        width: 12,
                                                      ),
                                                      WidgetUtil.middleText(
                                                          address == null
                                                              ? ''
                                                              : address
                                                                  .userName,
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 30,
                                              child: address == null
                                                  ? Container()
                                                  : GestureDetector(
                                                      onTap: () {
                                                        _selectAddressConfirm(
                                                            address);
                                                      },
                                                      child: Image.asset(
                                                        'assets/images/bottom_navi/phone3.png',
                                                        width: 40,
                                                        height: 40,
                                                      ),
                                                    ),
                                            )
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        height: 2,
                                      ),
                                    ],
                                  );
                                }
                                return SizedBox();
                              },
                            );
                          }

                          return GridView.extent(
                            maxCrossAxisExtent: colWidth,
                            padding: const EdgeInsets.only(
                              left: gridPadding,
                              right: gridPadding,
                              bottom: iconSize,
                            ),
                            mainAxisSpacing: gridSpacing,
                            crossAxisSpacing: gridSpacing,
                            childAspectRatio: gridRatio,
                            children: isManagerList
                                ? addressStore
                                    .managerList()
                                    .map((data) => _managerAddressCell(data))
                                    .toList()
                                : addressStore
                                    .staffList()
                                    .map((data) => _addressCell(data))
                                    .toList(),
                          );
                        },
                      ),
                    ),
              Positioned(
                top: constraints.maxHeight - iconSize,
                left: 0,
                width: constraints.maxWidth,
                height: iconSize,
                child: Container(
                  color: _showHistory || _showCalledHistory || _showCallHistory
                      ? Colors.white
                      : Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 30,
                            child: Image.asset(_isconnect
                                ? 'assets/images/led/ledG.png'
                                : 'assets/images/led/led2.png'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              '${_isconnect ? 'ON' : 'OFF'} LINE $connectMyId',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_showHistory) ...[
                            Container(
                              width: 90.0,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: WidgetUtil.basicText(
                                  'コール履歴',
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                onPressed: () async {
                                  _showCallLog();
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Container(
                              margin: EdgeInsets.only(
                                right: 8,
                              ),
                              width: 60.0,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showHistory = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Color.fromARGB(255, 64, 114, 200),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: WidgetUtil.basicText(
                                  '閉じる',
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                          if (_showCallHistory) ...[
                            Container(
                              width: 90.0,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: WidgetUtil.basicText(
                                  '通話履歴',
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                onPressed: () async {
                                  _showTalkLog();
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Container(
                              margin: EdgeInsets.only(
                                right: 8,
                              ),
                              width: 60.0,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showCallHistory = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Color.fromARGB(255, 64, 114, 200),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: WidgetUtil.basicText(
                                  '閉じる',
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                          if (_showCalledHistory)
                            Container(
                              margin: EdgeInsets.only(
                                right: 8,
                              ),
                              width: 60.0,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showCalledHistory = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Color.fromARGB(255, 64, 114, 200),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: WidgetUtil.basicText(
                                  '閉じる',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (!_showCalledHistory &&
                              !_showHistory &&
                              !_showCallHistory) ...[
                            SizedBox(
                              width: 60.0,
                              height: iconSize - 24.0,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "着信",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  _showCalled();
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            SizedBox(
                              width: 60.0,
                              height: iconSize - 24.0,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "通話",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  _showTalkLog();
                                },
                              ),
                            ),
                          ],
                          const SizedBox(
                            width: 8,
                          ),
                          if (!_showHistory &&
                              !_showCalledHistory &&
                              !_showCallHistory)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 4.0, right: 4.0, top: 8.0),
                              child: Text(
                                'Ver. $_version',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: () {
                              _toSetting();
                            },
                            child: Image.asset(
                              'assets/images/spana2.png',
                              width: spanaSize.width,
                              height: spanaSize.height,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (biosilverPopup != null) biosilverPopup!,
              if (_callStatuses.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _callStatuses.clear();
                    });
                  },
                  child: Opacity(
                    opacity: 0.5,
                    child: Container(
                      color: Colors.grey,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 400,
                    height: 100.0 * _callStatuses.length + 48,
                    color: Colors.white,
                    constraints: BoxConstraints(
                      maxHeight: callStatusBoxMaxHeight,
                    ),
                    child: ListView.builder(
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 8),
                              decoration: const BoxDecoration(
                                  border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey,
                                  width: 0.5,
                                ),
                              )),
                              child: Center(
                                  child: WidgetUtil.basicText('CALL STATUS')),
                            ),
                          );
                        }
                        return _callStatusPopupListItem(index - 1);
                      },
                      itemCount: _callStatuses.length + 1,
                    ),
                  ),
                ),
              ],
              if (_loading) ...[
                Container(
                  color: const Color.fromARGB(120, 0, 0, 0),
                ),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        }),
      ),
    );
  }

  @override
  void onConnect() {
    var useType = "0";
    if (AppManager.settings["DISPTYPE"] == '2') {
      useType = '1';
    }

    if (AppManager.isManager) {
      useType = 'S';
    }

    socketservice.delegatorLogin(useType);
  }

  @override
  void onDisConnect() {
    if (mounted) {
      context.read<AddressStore>().clear();
    }
    print('onDisConnect');
    setState(() {
      _isconnect = false;
    });
  }

  @override
  void onAppMessage(data) {
    print(data);
    String message = data['message'];
    if (message == 'from_server') {
      if (data['productName'] == '%logined') {
        return;
      }

      setState(() {
        _isconnect = true;
      });
      socketservice.io
          .emit("clients_status", [AppManager.settings['addressGroup']]);
      _checkFcm();
      _checkAccept();
    }

    if (!_ready) {
      return;
    }

    if (message == 'clients_status') {
      var statuses = data['data'];
      statuses.forEach((udid, value) {
        _setAddressStatus(udid, value['status']);
      });
    } else if (message == 'battery') {
      if (data['info']['UDID'] == null || data['info']['LOW'] == null) {
        return;
      }
      var addressStore = context.read<AddressStore>();
      var udid = data["info"]["UDID"];
      final battery = data["info"]["LOW"].toString();
      addressStore.setBattery(udid, battery);
    } else if (message == 'change_called') {
      if (data['info']['client'] != null) {
        audio.stopRingtone();
        var udid = data['info']['client'];
        var addressStore = context.read<AddressStore>();
        addressStore.setCalled(udid, 0);
      }
      if (AppManager.status == AppStatus.Call ||
          AppManager.status == AppStatus.Talk ||
          AppManager.status == AppStatus.Multi ||
          AppManager.status == AppStatus.MultiToTalk) {
      } else {
        _checkCalled();
      }
    } else if (message == 'login') {
      if (data['info']['client']['udid'] != null) {
        var udid = data['info']['client']['udid'];
        _setAddressStatus(udid, data['info']['client']['status']);
        var addressStore = context.read<AddressStore>();
        addressStore.setUnableCommunicate(udid, '');
      }
    } else if (message == 'status_change') {
      if (data["info"]["MYID"] != null && data["info"]["STATUS"] != null) {
        if (!mounted) {
          return;
        }
        var addressStore = context.read<AddressStore>();
        var udid = data["info"]["MYID"];
        final status = data["info"]["STATUS"].toString();
        final address = addressStore.find(udid);
        if (address != null) {
          if (status == '1' ||
              status == '2' ||
              status == '3' ||
              status == '4' ||
              status == '5') {
            addressStore.setCalled(udid, 0);
          }
          if (address.call == 1) {
            audio.stopRingtone();
            addressStore.setCall(udid, 0);
            _openCallStatusPopup();

            if (data["info"]["STATUS"].toString() == '2') {
              addressStore.setSupported(udid, 1);
            }
          }
        }
        _setAddressStatus(data["info"]["MYID"], data["info"]["STATUS"]);
      }
    } else if (message == 'viewcan_image') {
      if (data["info"] == null) {
        return;
      }
      if (data["info"]["udid"] == null || data["info"]["data"] == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      var addressStore = context.read<AddressStore>();
      var udid = data["info"]["udid"];
      final index = addressStore.findAddress(udid);
      if (index < 0) {
        return;
      }
      String image = data["info"]["data"];
      var base64Pos = image.indexOf('base64,');
      if (base64Pos >= 0) {
        image = image.substring(base64Pos + 'base64,'.length);
      }
      var image64 = image.replaceAll("\r\n", "");
      addressStore.setLiveImage(udid, image64);
    } else if (message == 'call') {
      if (data["info"]["udid"] == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      var addressStore = context.read<AddressStore>();
      var udid = data["info"]["udid"];
      final index = addressStore.findAddress(udid);
      if (index < 0) {
        return;
      }
      var address = context.read<AddressStore>().find(udid)!;
      if (!AppManager.isAuthReceive(address)) {
        socketservice.io.emit("call_not_auth", [address.id]);
        AppManager.toast("${address.name}から着信がありました",
            bgColor: Colors.blue, sec: 5);
        return;
      }

      if (AppManager.status == AppStatus.Call ||
          AppManager.status == AppStatus.Talk ||
          AppManager.status == AppStatus.Multi ||
          AppManager.status == AppStatus.MultiToTalk) {
      } else {
        audio.ringtone();
      }
      _called(udid);
    } else if (message == 'call_talking') {
      if (data["info"]["udid"] == null) {
        return;
      }
      var addressStore = context.read<AddressStore>();
      addressStore.setCalled(data["info"]["udid"], 1);
    } else if (message == 'call_cancel') {
      if (data["udid"] == null) {
        return;
      }
      if (mounted) {
        context.read<AddressStore>().setCall(data["udid"], 0);
        context.read<AddressStore>().setCalled(data["udid"], 1);
      }
      audio.stopRingtone();
      _openCallStatusPopup();
    } else if (message == 'unable_to_communicate') {
      if (data["info"] == null) {
        return;
      }
      if (data["info"]["udid"] == null) {
        return;
      }
      var udid = data["info"]["udid"];
      var addressStore = context.read<AddressStore>();
      addressStore.setUnableCommunicate(udid, '1');
    } else if (message == 'push_notification') {
      audio.stopRingtone();
      if (!mounted) {
        return;
      }
      if (AppManager.status == AppStatus.Call ||
          AppManager.status == AppStatus.Talk ||
          AppManager.status == AppStatus.Multi ||
          AppManager.status == AppStatus.MultiToTalk) {
      } else {
        _checkCalled();
      }
    }
  }

  @override
  void onMessage(data) {}

  @override
  void onTalkMessage(data) {}

  @override
  void onSensorAlertsChange() {
    var addressStore = context.read<AddressStore>();
    sensorService.alerts.forEach((key, value) {
      addressStore.setSensor(key, value);
    });
    sensorService.biosilverAlerts.forEach((key, value) {
      addressStore.setSensors(key, value);
    });
  }
}
