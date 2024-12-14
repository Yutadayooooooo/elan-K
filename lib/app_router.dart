import 'dart:convert';

import 'package:ami/app_define.dart';
import 'package:ami/pages/room/room_page.dart';
import 'package:ami/pages/room/room_talk_page.dart';
import 'package:ami/pages/setting/setting_account_list_page.dart';
import 'package:ami/pages/setting/setting_info_message_page.dart';
import 'package:ami/pages/setting/setting_info_photo_page.dart';
import 'package:ami/pages/setting/setting_info_video_page.dart';
import 'package:ami/pages/setting/setting_notify_group_page.dart';
import 'package:ami/pages/setting/setting_sleep_mode_page.dart';
import 'package:ami/pages/talk/talk_page.dart';
import 'package:ami/pages/tutorial/tutorial_page.dart';
import 'package:ami/pages/webview/webview_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/pages/login/login_page.dart';
import '/pages/setting/setting_page.dart';
import '/pages/setting/setting_about_page.dart';
import '/pages/home_page.dart';
import 'notifiers/app_notifier.dart';

class AppRoute {
  static const homePage = '/home_page';
  static const talkPage = '/talk_page';
  static const loginPage = '/login';
  static const tutorialPage = '/tutorial';
  static const settingPage = '/setting';
  static const settingAboutPage = '/setting/about';
  static const settingInfoVideoPage = '/setting/info_video';
  static const settingInfoPhotoPage = '/setting/info_photo';
  static const settingInfoMessagePage = '/setting/info_message';
  static const settingNotifyGroupPage = '/setting/notify_group';
  static const settingAccountListPage = '/setting/account_list';
  static const settingSleepModePage = '/setting/sleep_mode';
  static const webviewPage = '/webview';
  static const roomPage = '/room_page';
  static const roomTalkPage = '/room_talk_page';


  static Future<GoRouter> createRouter(bool isInitialize, bool isLogin) async {
    var initialLocaion = homePage;
    if (!isInitialize) {
      initialLocaion = tutorialPage;
    } else if (!isLogin) {
      initialLocaion = loginPage;
    }

    if (AppDefine.room) {
      initialLocaion = isLogin ? roomPage : loginPage;
    }

    return GoRouter(
      debugLogDiagnostics: true,
      initialLocation: initialLocaion,
      // refreshListenable: context.read<AppStore>(),
      // redirect: (context, GoRouterState state) {
      //   if (!context.read<AppStore>().isInitialized) {
      //     return state.path == tutorialPage ? null : tutorialPage;
      //   }
      //
      //   if (!context.read<AppStore>().isLoggedIn) {
      //     return state.path == loginPage ? null : loginPage;
      //   }
      //
      //   return null;
      // },
      routes: <RouteBase> [
        GoRoute(
            name: 'home',
            path: homePage,
            builder: (context, state) => HomePage()
        ),
        GoRoute(
          path: talkPage,
          builder: (BuildContext context, GoRouterState state) {
            return TalkPage();
          },
        ),
        GoRoute(
          path: loginPage,
          builder: (BuildContext context, GoRouterState state) {
            return LoginPage();
          },
        ),
        GoRoute(
          path: tutorialPage,
          builder: (BuildContext context, GoRouterState state) {
            return TutorialPage();
          },
        ),
        GoRoute(
          path: settingPage,
          builder: (BuildContext context, GoRouterState state) {
            return SettingPage();
          },
          routes: [
            GoRoute(
              path: 'about',
              builder: (context, state) => const SettingAboutPage(),
            ),
            GoRoute(
              path: 'info_message',
              builder: (context, state) => SettingInfoMessagePage(),
            ),
            GoRoute(
              path: 'info_video',
              builder: (context, state) => SettingInfoVideoPage(),
            ),
            GoRoute(
              path: 'info_photo',
              builder: (context, state) => SettingInfoPhotoPage(),
            ),
            GoRoute(
              path: 'notify_group',
              builder: (context, state) => SettingNotifyGroupPage(),
            ),
            GoRoute(
              path: 'account_list',
              builder: (context, state) => SettingAccountListPage(),
            ),
            GoRoute(
              path: 'sleep_mode',
              builder: (context, state) => SettingSleepModePage(),
            ),
          ],
        ),
        GoRoute(
          name: 'webview',
          path: webviewPage,
          builder: (BuildContext context, GoRouterState state) {
            final mp = state.uri.queryParameters;
            String title = mp['title']!;
            String url = mp['url']!;
            return WebviewPage(title: title, url: url);
          },
        ),
        GoRoute(
            name: 'room',
            path: roomPage,
            builder: (context, state) => RoomPage()
        ),
        GoRoute(
          path: roomTalkPage,
          builder: (BuildContext context, GoRouterState state) {
            return RoomTalkPage();
          },
        ),
      ],
    );
  }

}
