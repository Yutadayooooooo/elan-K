import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_manager.dart';
import '/app_define.dart';
import '/helpers/widget_helper.dart';

class SettingAccountListPage extends StatefulWidget {
  const SettingAccountListPage({super.key});

  @override
  _SettingAccountListPageState createState() => _SettingAccountListPageState();
}

class _SettingAccountListPageState extends State<SettingAccountListPage> {
  bool _loading = true;
  List<dynamic> _data = [];
  var title = '';

  final _listHeight = 44.0;
  final TextStyle _titleTextStyle1 = const TextStyle(
    fontSize: 14,
  );

  @override
  void initState() {
    super.initState();

    Future(() {
      _getData();
    });
  }

  Future<void> _getData() async {
    setState(() {
      _loading = true;
    });

    final code = AppManager.delegatorCode;
    final dio = Dio();
    var url = '${AppDefine.baseURL}elan/api/info_text?code=${code}&token=${AppManager.settings['api_token']}';
    var data = await dio.get(
      url,
    ).then((response) {
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

    setState(() {
      _data = data['list'];
    });
  }

  Widget _listContainer(int index) {
    final item = _data[index];
    final itemId = item['id'].toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: InkWell(
        onTap: () {

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
              WidgetUtil.basicText(item['name']),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 18.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    List<Widget> actions = [];
    actions.add(TextButton(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 16),
      ),
      onPressed: null,
      child: const Text('追加'),
    ));

    return Scaffold(
      appBar: WidgetUtil.appBar('アカウント一覧',
        actions: actions,
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
            WidgetUtil.loadingIndicator,
        ],
      ),
    );
  }
}
