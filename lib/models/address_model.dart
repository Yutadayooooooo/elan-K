import 'dart:convert';
import 'dart:typed_data';

class Address {
  String id;
  String name;
  String code;
  String type;
  int status;
  int call;
  int called;
  int battery = 0;
  DateTime? calledTime;
  int supported = 0;
  String userType;
  String userName = '';
  String photo = '';
  String liveimage = '';
  String sensor = '';
  String unableCommunication = '';
  List<dynamic> sensors = [];

  Address({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.status,
    required this.call,
    required this.called,
    required this.userType,
    required this.photo,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    var id = json.keys.contains("id") ? json['id'] : json['TARGET_ID'];
    var name = json.keys.contains("name") ? json['name'] : json['NAME'];
    var userName = json.keys.contains("userName") ? json['userName'] : json['USER_NAME'];
    var type = json.keys.contains("type") ? json['type'] : (json.keys.contains("userType") ? json['userType'] : json['USER_TYPE']);
    var photo = json.keys.contains("photo") ? json['photo'] : json['PHOTO'];

    var code = '';
    if (json.keys.contains("code")) {
      code = json['code'].toString();
    } else if (json.keys.contains("bookGrp")) {
      code = json['bookGrp'].toString();
    } else if (json.keys.contains("BOOK_GRP")) {
      code = json['BOOK_GRP'].toString();
    }

    var address = Address(
      id: id,
      name: name,
      code: code,
      type: type,
      status: int.parse(json['status']),
      call: int.parse(json['call']),
      called: int.parse(json['called']),
      userType: json['userType'],
      photo: photo
    );
    if (json.keys.contains("userName")) {
      address.userName = userName;
    }
    return address;
  }

  static List<Address> fromJsonList(List<dynamic> json) {
    var list = <Address>[];
    for (var i = 0; i < json.length; i++) {
      var address = Address.fromJson(json[i]);
      list.add(address);
    }
    return list;
  }

  Uint8List photoBytes() {
    Uint8List bytes = Uint8List(0);

    if (photo.isEmpty) {
      print('photo isEmpty');
      return bytes;
    }

    var base64Pos = photo.indexOf('base64,');
    if (base64Pos >= 0) {
      bytes = base64Decode(photo.substring(base64Pos + 'base64,'.length));
    }

    return bytes;
  }
}