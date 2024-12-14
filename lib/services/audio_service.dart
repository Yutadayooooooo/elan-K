import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
// import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '/app_manager.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  AudioService._internal(
  );

  late AudioCache _audioCache;
  AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayer? _ringtone;
  AudioPlayer? _call;
  AudioPlayer? _buttonCall;
  AudioPlayer? _spo2;

  factory AudioService() {
    return _instance;
  }

  Future<void> call() async {
    if (_call == null) {
      _call = AudioPlayer();
    }

    await _call!.setSource(AssetSource('sounds/call.mp3'));
    await _call!.setReleaseMode(ReleaseMode.loop);
    await _call!.resume();
    // await _call.setAsset('assets/sounds/call.mp3');
    // await _call.play();
  }

  Future<void> stopCall() async {
    if (_call == null) {
      return;
    }
    await _call!.stop();
    _call = null;
  }

  Future<void> buttonCall() async {
  //   if (_buttonCall != null) {
  //     return;
  //   }
  //   _buttonCall = AssetsAudioPlayer();
  //   await _buttonCall!.open(Audio(
  //     '/assets/sounds/sound1.mp3',
  //   ), loopMode: LoopMode.single);
  //   await _buttonCall!.play();
  }

  Future<void> stopButtonCall() async {
  //   if (_buttonCall == null) {
  //     return;
  //   }
  //   await _buttonCall!.stop();
  //   _buttonCall!.dispose();
  //   _buttonCall = null;
  }

  Future<void> ringtone() async {
    if (_ringtone == null) {
      _ringtone = AudioPlayer();
    }

    await _ringtone!.setSource(AssetSource('sounds/ringtone.mp3'));
    await _ringtone!.setReleaseMode(ReleaseMode.loop);
    await _ringtone!.resume();
  }

  Future<void> assetRingtone() async {
    // _ringtone = AssetsAudioPlayer();
    // await _ringtone!.open(Audio(
    //   '/assets/sounds/ringtone.mp3',
    // ), loopMode: LoopMode.single);
    // await _ringtone!.play();
  }

  // Future<void> dlRingtone() async {
  //   var filename = 'dlringtone.mp3';
  //   String localpath = '${(await getApplicationDocumentsDirectory()).path}/$filename';
  //   print(localpath);
  //   var exist = await File(localpath).exists();
  //   if (!exist) {
  //     print('file none');
  //     return;
  //   }
  //   _ringtone = AssetsAudioPlayer();
  //   await _ringtone!.open(Audio.file(
  //     localpath,
  //   ), loopMode: LoopMode.single);
  //   await _ringtone!.play();
  // }

  Future<void> stopRingtone() async {
    if (_ringtone == null) {
      return;
    }
    await _ringtone!.stop();
    await _ringtone!.dispose();
    _ringtone = null;
  //   print('[DEBUG PRINT] stop  ringtone');
  //   if (_ringtone != null) {
  //     await _ringtone!.stop();
  //     _ringtone!.dispose();
  //     _ringtone = null;
  //   }
  }

  Future<void> spo2() async {
  //   if (_spo2 != null) {
  //     return;
  //   }
  //   _spo2 = AssetsAudioPlayer();
  //   await _spo2!.open(Audio(
  //       '/assets/sounds/spo2.mp3'
  //   ), loopMode: LoopMode.single);
  //   await _spo2!.play();
  }

  Future<void> stopSpo2() async {
  //   if (_spo2 == null) {
  //     return;
  //   }
  //   await _spo2?.stop();
  //   _spo2?.dispose();
  //   _spo2 = null;
  }
}