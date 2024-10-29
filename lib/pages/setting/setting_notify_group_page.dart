import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/helpers/widget_helper.dart';
import '/app_manager.dart';
import '/app_define.dart';

class SettingNotifyGroupPage extends StatefulWidget {
  const SettingNotifyGroupPage({super.key});

  @override
  SettingNotifyGroupPageState createState() => SettingNotifyGroupPageState();
}

class SettingNotifyGroupPageState extends State<SettingNotifyGroupPage> {
  var _loading = true;
  List<dynamic> _data = [];
  List<String> values = [];
  final _listHeight = 44.0;
  final TextStyle _titleTextStyle1 = const TextStyle(
    fontSize: 14,
  );
  bool _savedSwitch = false;

  @override
  void initState() {
    super.initState();
    print('notify group initState');

    Future(() {
      _getData();
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    print('notify group didChangeDependencies');
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getData() async {
    final url = "${AppDefine.baseURL}app/group_list?code=${AppManager.settings['DELEGATORCODE']}&token=${AppManager.settings['api_token']}";
    print(url);

    final dio = Dio();
    var data = await dio.get(
      url,
    ).then((response) {
      print(response.data);
      return response.data;
    }).catchError((err) {
      print(err);
      return null;
    });

    setState(() {
      _loading = false;
      if (data != null) {
        _data = data['data'];
      }
    });

  }

  Widget _listContainer(int index) {
    final data = _data[index];
    var isSwitch = AppManager.authReceives.containsKey(data['code']);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color.fromARGB(255, 220, 220, 220)),
        ),
      ),
      height: _listHeight,
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            data['name'],
            style: _titleTextStyle1,
          ),
          CupertinoSwitch(
            value: isSwitch,
            onChanged: (value) async {
              print(value);
              String val = '0';
              if (value) {
                val = '1';
              }
              if (value) {
                AppManager.authReceives[data['code']] = '1';
              } else {
                AppManager.authReceives.remove(data['code']);
              }

              final sharedPreferences = await SharedPreferences.getInstance();
              await sharedPreferences.setString('authreceives', json.encode(AppManager.authReceives));

              setState(() {
                _savedSwitch = !_savedSwitch;
              });
            },
            activeColor: Colors.red,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通話権限'),
        backgroundColor: WidgetUtil.iosNavbarBG,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              return _listContainer(index);
            },
            itemCount: _data.length,
          ),
          if (_loading)
            ... [
              Container(
                color: const Color.fromARGB(120, 0, 0, 0),
              ),
              const Center(child: CircularProgressIndicator()),
            ],
        ],
      ),
    );
  }
}
