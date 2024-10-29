
import 'package:ami/pages/tutorial/tutorial_page.dart';
import 'package:ami/pages/webview/webview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/pages/login/login_page.dart';
import '/pages/setting/setting_page.dart';
import '/pages/setting/setting_about_page.dart';
import '/pages/home_page.dart';

const homePage = '/home_page';
const loginPage = '/login';
const tutorialPage = '/tutorial';
const settingPage = '/setting';
const settingAboutPage = '/setting/about';
const webviewPage = '/webview';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
  routes: [
    GoRoute(
        name: 'home',
        path: homePage,
        builder: (context, state) => HomePage()
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
  ],
));