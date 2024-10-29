import 'package:ami/services/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_define.dart';
import '../../app_router.dart';
import '../../notifiers/app_notifier.dart';

class TutorialPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double fontSize = 14;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          var bgImage = constraints.maxWidth > 500 ? 'assets/images/tutorial/first_iPad.png' : 'assets/images/tutorial/first_iPhone.png';
          var douiImage = constraints.maxWidth > 500 ? 'assets/images/tutorial/doui_Pad.png' : 'assets/images/tutorial/doui_iPhone.png';
          var douiWidth = constraints.maxWidth > 600 ? 300.0 : 190.0;
          var douiHeight = douiWidth / 88 * 29;

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(bgImage),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned(
                top: constraints.maxHeight / 2 -20,
                left: 20,
                width: constraints.maxWidth - 40,
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        child: Image.asset(
                          douiImage,
                          width: douiWidth,
                          height: douiHeight,
                        ),
                        onTap: () async {
                          var prefs = await SharedPreferences.getInstance();
                          await prefs.setBool("isInitialized", true);
                          context.go(AppRoute.loginPage);
                        }
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: constraints.maxHeight > 800 ? 300 : 200,
                left: 40,
                width: constraints.maxWidth - 80,
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSize,
                      ),
                      children: [
                        const TextSpan(
                          text: 'ご利用には',
                        ),
                        TextSpan(
                          text: '利用規約',
                          style: const TextStyle(
                            color: Colors.teal,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = () async {
                            context.pushNamed('webview', queryParameters: {'title': '利用規約', 'url': AppDefine.kiyakuURL});
                          },
                        ),
                        const TextSpan(
                          text: 'および',
                        ),
                        TextSpan(
                          text: '個人情報保護方針',
                          style: const TextStyle(
                            color: Colors.teal,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            print('"個人情報保護方針" がタップされました');
                            context.pushNamed('webview', queryParameters: {'title': '個人情報保護方針', 'url': AppDefine.policyURL});
                          },
                        ),
                        const TextSpan(
                          text: 'への同意が必要です。',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 200,
                left: 40,
                width: constraints.maxWidth - 80,
                child: const Center(
                  child: Text('サービス事業者より申し込みを行ってください。'),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}