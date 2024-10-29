import 'package:flutter/material.dart';
import 'login_page.dart' show LoginPage;
import '/utils/my_model.dart';

export '/utils/my_model.dart';

class LoginModel extends MyModel<LoginPage> {

  FocusNode codeFocusNode = FocusNode();
  TextEditingController codeTextController = TextEditingController();
  String? Function(BuildContext, String?)? codeTextControllerValidator;

  FocusNode idFocusNode = FocusNode();
  TextEditingController idTextController = TextEditingController();
  String? Function(BuildContext, String?)? idTextControllerValidator;

  FocusNode passwordFocusNode = FocusNode();
  TextEditingController passwordTextController = TextEditingController();
  late bool passwordVisibility;
  String? Function(BuildContext, String?)? passwordTextControllerValidator;

  late bool validated = true;
  String? emailError;
  String? passwordError;

  @override
  void initState(BuildContext context) {
    passwordVisibility = false;

    codeTextControllerValidator = (context, value) {
      if (value == null || value.isEmpty) {
        return 'コードを入力してください';
      }
      return null;
    };

    idTextControllerValidator = (context, value) {
      if (value == null || value.isEmpty) {
        return 'ユーザーIDを入力してください';
      }
      return null;
    };

    passwordTextControllerValidator = (context, value) {
      if (value == null || value.isEmpty) {
        return 'パスワードを入力してください';
      }
      return null;
    };
  }

  @override
  void dispose() {
    codeFocusNode.dispose();
    codeTextController.dispose();

    idFocusNode.dispose();
    idTextController.dispose();

    passwordFocusNode.dispose();
    passwordTextController.dispose();
  }
}
