import 'dart:convert';
import 'package:ami/notifiers/app_notifier.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_define.dart';
import '../../app_manager.dart';
import '../../app_router.dart';
import '../../helpers/widget_helper.dart';
import 'login_model.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late LoginModel _model;
  var _loginMode = 'staff';
  var _loading = false;

  @override
  void initState() {
    super.initState();

    _initModel();

    Future(() async {

      if (await Permission.camera.status == PermissionStatus.denied) {
        await Permission.camera.request();
      }
      if (await Permission.microphone.status == PermissionStatus.denied) {
        await Permission.microphone.request();
      }

      final prefs = await SharedPreferences.getInstance();
      String? loginCode = prefs.getString('login_code');
      if (loginCode != null) {
        _model.codeTextController.text = loginCode;
      }
    });

  }

  void _initModel() {
    _model = createModel(context, () => LoginModel());
  }

  String _loginURL() {
    if (AppDefine.amiApp) {
      return '${AppDefine.baseURL}app/login';
    }
    return '${AppDefine.baseURL}app/v4/loginv6.php';
  }

  Future<void> _login() async {
    if (primaryFocus != null) {
      primaryFocus?.unfocus();
    }
    setState(() {
      _loading = true;
    });

    final url = _loginURL();
    print(url);

    final code = _model.codeTextController.text;
    final id = _model.idTextController.text;
    final password = _model.passwordTextController.text;

    if (code.isEmpty || id.isEmpty || password.isEmpty) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("確認"),
            content: const Text("ログイン情報を入力してください。"),
            actions: <Widget>[
              SimpleDialogOption(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );
      return;
    }

    final dio = Dio();
    final data = await dio.post(
      url,
      data: FormData.fromMap({'delegatorCode': code, 'userID': id, 'password': password, 'code': code, 'user_id': id})
    ).then((response) {
      print(response.data);

      if (response.data['cnt'] == '1') {
        return response.data;
      }
      return null;
    }).catchError((err) {
      print(err);
      return null;
    });


    setState(() {
      _loading = false;
    });

    if (data == null) {
      WidgetUtil.showSimpleDialog(context, 'ログイン情報を確認してください。');
      return;
    }

    var isMaspro = false;

    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool('login', true);
    await prefs.setBool('manager', false);
    await prefs.setString('login_code', code);
    await prefs.setString('address', json.encode(data['address']));
    // print(json.encode(data['address']));
    await prefs.setString('autoreceive', json.encode(data['autoreceive']));

    Map<String, dynamic> settings = data['settings'];

    bool isAnminMode = false;
    for (var k in settings.keys) {
      if (k == 'ANMINMODEFLG' && settings[k] != '0') {
        isAnminMode = true;
      }
    }
    if (isAnminMode) {
      settings["SLEEPMODE"] = "0";
    }
    var mcsType = settings['MCSTYPE'];
    print('login mscType: ${mcsType}');
    if (mcsType == '3') {
      settings['DISPTYPE'] = '1';
    }

    await prefs.setString('settings', json.encode(settings));
    AppManager.saveAppSetting("ANMINMODEFLG", isAnminMode ? "1" : "0");
    // if (settings['MASPROSENSOR'] == "1") {
    //   isMaspro = true;
    //   Navigator.of(context).pushReplacementNamed("/sensorweb");
    //   return;
    // }
    if (mcsType == '5' || mcsType == '4' || mcsType == '3') {
      context.go(AppRoute.homePage);
    } else {
      WidgetUtil.showSimpleDialog(context, 'ログイン情報を確認してください。');
    }

    return;
  }

  Future<void> _staffLogin() async {
    setState(() {
      _loading = true;
    });
    var url = '${AppDefine.baseURL}app/staff_login';

    final code = _model.codeTextController.text;
    final id = _model.idTextController.text;
    final password = _model.passwordTextController.text;

    if (code.isEmpty || id.isEmpty || password.isEmpty) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("確認"),
            content: const Text("ログイン情報を入力してください。"),
            actions: <Widget>[
              SimpleDialogOption(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );
      return;
    }

    final dio = Dio();
    var data = await dio.post(
        url,
        data: FormData.fromMap({'delegatorCode': code, 'userID': id, 'password': password, 'code': code, 'user_id': id})
    ).then((response) {
      if (response.data['cnt'] == '1') {
        return response.data;
      }
      return null;
    }).catchError((err) {
      print(err);
      return null;
    });

    setState(() {
      _loading = false;
    });

    if (data == null) {
      WidgetUtil.showSimpleDialog(context, 'ログイン情報を確認してください。');
      return;
    }

    print(data);
    print(DateTime.now());

    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool('login', true);
    await prefs.setBool('manager', true);
    await prefs.setString('login_code', code);
    await prefs.setString('address', json.encode(data['address']));
    await prefs.setString('autoreceive', json.encode(data['autoreceive']));
    await prefs.setString('authreceives', json.encode(data['authReceives']));
    await prefs.setString('codes', json.encode(data['codes']));

    print(DateTime.now());
    Map<String, dynamic> settings = data['settings'];

    var mcsType = settings['MCSTYPE'];
    if (mcsType == '3') {
      settings['DISPTYPE'] = '1';
    }

    print(DateTime.now());
    await prefs.setString('settings', json.encode(settings));
    AppManager.saveAppSetting("ANMINMODEFLG", "1");

    if (!mounted) return;

    print(DateTime.now());
    context.go(AppRoute.homePage);

    return;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    double verticalPadding = 150.0;
    double verticalPadding2 = 40.0;
    if (size.height < 700) {
      verticalPadding = 80.0;
      verticalPadding2 = 10.0;
    }
    double paddingX = 50;
    if (size.width > 700) {
      paddingX = 200;
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 238, 239, 243),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: paddingX),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 247, 247, 247),
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: EdgeInsets.symmetric(vertical: verticalPadding2, horizontal: 22.0),
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('コード'),
                      const SizedBox(height: 4,),
                      TextField(
                        controller: _model.codeTextController,
                        decoration: const InputDecoration(
                          fillColor: Colors.white,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 220, 220, 220),
                            ),
                          ),
                          hintText: '',
                          isDense: true,
                          // errorText: _passErr.isEmpty ? null : _passErr,
                        ),
                        // obscureText: true,
                      ),
                      const SizedBox(height: 12.0,),
                      const Text("ユーザーID"),
                      const SizedBox(height: 4,),
                      TextField(
                        controller: _model.idTextController,
                        decoration: const InputDecoration(
                          fillColor: Colors.white,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 220, 220, 220),
                            ),
                          ),
                          hintText: '',
                          isDense: true,
                          // errorText: _passErr.isEmpty ? null : _passErr,
                        ),
                        // obscureText: true,
                      ),
                      const SizedBox(height: 12.0,),
                      const Text("パスワード"),
                      const SizedBox(height: 4,),
                      TextField(
                        controller: _model.passwordTextController,
                        decoration: const InputDecoration(
                          fillColor: Colors.white,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 220, 220, 220),
                            ),
                          ),
                          hintText: '',
                          isDense: true,
                          // errorText: _passErr.isEmpty ? null : _passErr,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 50,),
                      Center(
                        child: SizedBox(
                          width: size.width - 60 > 200 ? 200 : size.width - 60,
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: _loginMode == 'user' ? Color.fromARGB(255, 115, 176, 236) :  Color.fromARGB(255, 115, 206, 146),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              if (_loginMode == 'staff') {
                                _staffLogin();
                                return;
                              }
                              _login();
                            },
                            child: const Text("ログイン"),
                          ),
                        ),
                      ),
                      if (1 == 1)
                        ... [
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                textStyle: const TextStyle(fontSize: 14),
                              ),
                              onPressed: () {
                                setState(() {
                                  _loginMode = _loginMode == 'user' ? 'staff' : 'user';
                                });
                              },
                              child: Text(_loginMode == 'user' ? 'スタッフはこちら' : 'ユーザーはこちら'),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            Align(
              alignment: FractionalOffset.center,
              child: Container(
                color: Colors.grey.withOpacity(0.3),
                child: const Padding(
                  padding: EdgeInsets.all(5.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}