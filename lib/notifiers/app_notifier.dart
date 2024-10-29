import 'package:flutter/material.dart';

class AppStore with ChangeNotifier {

  bool isInitialized = false;
  bool isLoggedIn = false;
  bool connect = false;
  String selectCode = '';

  void setIsInitialized(value) {
    isInitialized = value;
    notifyListeners();
  }

  void setIsLoggedIn(value) {
    isLoggedIn = value;
    notifyListeners();
  }

  void setConnect(value) {
    connect = value;
    notifyListeners();
  }

  void setSelectCode(value) {
    selectCode = value;
    notifyListeners();
  }
}