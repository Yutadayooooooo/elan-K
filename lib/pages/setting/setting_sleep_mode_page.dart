import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../app_define.dart';
import '../../app_manager.dart';
import '../../helpers/widget_helper.dart';

class SettingSleepModePage extends StatefulWidget {

  @override
  SettingSleepModePageState createState() => SettingSleepModePageState();
}

class SettingSleepModePageState extends State<SettingSleepModePage> {
  bool _loading = false;
  var _init = true;
  String? _err;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  List<dynamic> _data = [];

  @override
  void initState() {
    super.initState();

    _data.add(AppManager.appsettings['SLEEP_START']);
    _data.add(AppManager.appsettings['SLEEP_END']);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showCustomTimePicker(BuildContext context, index) async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        var selectedHour = 0;
        var selectedMinute = 0;
        var settingKey = index == 0 ? 'SLEEP_START' : 'SLEEP_END';
        List<String> parts = AppManager.appsettings[settingKey].split(':');
        selectedHour = int.parse(parts[0]);
        selectedMinute = int.parse(parts[1]);
        print(AppManager.appsettings[settingKey]);
        print(selectedHour);
        print(selectedMinute);
        return Container(
          height: 250,
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              // 完了ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 20), // 左スペース
                  TextButton(
                    onPressed: () {
                      print(selectedHour);
                      print(selectedMinute);
                      final val = (selectedHour < 10 ? '0' : '') + selectedHour.toString() + ":" + (selectedMinute < 10 ? '0' : '') + selectedMinute.toString();
                      AppManager.saveAppSetting(settingKey, val);
                      setState(() {
                        _data[index] = val;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      '完了',
                      style: TextStyle(color: Colors.blue, fontSize: 18),
                    ),
                  ),
                ],
              ),
              // カスタムピッカー
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 時間ピッカー
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedHour,
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (int value) {
                          setState(() {
                            selectedHour = value;
                          });
                        },
                        children: List.generate(24, (index) {
                          return Center(
                            child: Text(
                              '${index}時',
                              style: TextStyle(fontSize: 20),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 分ピッカー
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: (selectedMinute / 15).toInt(),
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (int value) {
                          setState(() {
                            selectedMinute = value * 15;
                          });
                        },
                        children: List.generate(4, (index) {
                          final minute = index * 15; // 15分刻み
                          final minText = (minute < 10 ? '0' : '') + minute.toString();
                          return Center(
                            child: Text(
                              '${minText}分',
                              style: TextStyle(fontSize: 20),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTime(BuildContext context, index) async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        var hours = 0;
        var minutes = 0;
        var settingKey = index == 0 ? 'SLEEP_START' : 'SLEEP_END';
        if (index == 0) {
          List<String> parts = AppManager.appsettings[settingKey].split(':');
          hours = int.parse(parts[0]);
          minutes = int.parse(parts[1]);
        }
        Duration selectedTime = Duration(hours: hours, minutes: minutes);
        return Container(
          height: 250,
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              // モーダル上部の完了ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 20), // 左側のスペース
                  TextButton(
                    onPressed: () {
                      print(selectedTime);
                      Navigator.pop(context); // モーダルを閉じる
                    },
                    child: Text(
                      '完了',
                      style: TextStyle(color: Colors.blue, fontSize: 18),
                    ),
                  ),
                ],
              ),
              // CupertinoTimerPicker
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: selectedTime,
                  onTimerDurationChanged: (Duration newDuration) {
                    setState(() {
                      selectedTime = newDuration;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _listContainer(int index) {
    final item = _data[index];
    final label = index == 0 ? '寝る時間' : '起きる時間';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: InkWell(
        onTap: () {
          _showCustomTimePicker(context, index);
        },
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color.fromARGB(255, 220, 220, 220)),
            ),
          ),
          height: WidgetUtil.listHeight,
          padding: const EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              WidgetUtil.basicText(label),
              WidgetUtil.basicText(item),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: WidgetUtil.appBar('就寝モード',
        backgroundColor: WidgetUtil.iosNavbarBG,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return _listContainer(index);
              },
              itemCount: _data.length,
            ),
            if (_loading)
              WidgetUtil.loadingIndicator,
          ],
        ),
      ),
    );
  }
}
