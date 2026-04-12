import 'package:flutter/services.dart';
import '../constants.dart';

class NativeBridge {
  static const _channel = MethodChannel(AppConstants.channelName);
  static const _eventChannel = EventChannel(AppConstants.eventChannelName);

  static Future<String> getProotPath() async {
    return await _channel.invokeMethod('getProotPath');
  }

  static Future<String> getArch() async {
    return await _channel.invokeMethod('getArch');
  }

  static Future<String> getFilesDir() async {
    return await _channel.invokeMethod('getFilesDir');
  }

  static Future<String> getNativeLibDir() async {
    return await _channel.invokeMethod('getNativeLibDir');
  }

  static Future<bool> isBootstrapComplete() async {
    return await _channel.invokeMethod('isBootstrapComplete');
  }

  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _channel.invokeMethod('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> extractRootfs(String tarPath) async {
    return await _channel.invokeMethod('extractRootfs', {'tarPath': tarPath});
  }

  // VM lifecycle
  static Future<bool> vmCreate(String name) async {
    return await _channel.invokeMethod('vmCreate', {'name': name});
  }

  static Future<bool> vmDelete(String name) async {
    return await _channel.invokeMethod('vmDelete', {'name': name});
  }

  static Future<List<Map<String, dynamic>>> vmList() async {
    final result = await _channel.invokeMethod<List>('vmList');
    return result?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  static Future<String> runInProot(String command, {int timeout = 900, String vmName = 'ubuntu'}) async {
    return await _channel.invokeMethod('runInProot', {
      'command': command,
      'timeout': timeout,
      'vmName': vmName,
    });
  }

  static Future<bool> setupDirs() async {
    return await _channel.invokeMethod('setupDirs');
  }

  static Future<bool> writeResolv() async {
    return await _channel.invokeMethod('writeResolv');
  }

  static Future<String> readRootfsFile(String path, {String vmName = 'ubuntu'}) async {
    return await _channel.invokeMethod('readRootfsFile', {'path': path, 'vmName': vmName});
  }

  static Future<bool> writeRootfsFile(String path, String content, {String vmName = 'ubuntu'}) async {
    return await _channel.invokeMethod('writeRootfsFile', {
      'path': path,
      'content': content,
      'vmName': vmName,
    });
  }

  static Future<bool> hasStoragePermission() async {
    return await _channel.invokeMethod('hasStoragePermission');
  }

  static Future<bool> requestStoragePermission() async {
    return await _channel.invokeMethod('requestStoragePermission');
  }

  static Future<String> getExternalStoragePath() async {
    return await _channel.invokeMethod('getExternalStoragePath');
  }

  static Future<bool> isBatteryOptimized() async {
    return await _channel.invokeMethod('isBatteryOptimized');
  }

  static Future<bool> requestBatteryOptimization() async {
    return await _channel.invokeMethod('requestBatteryOptimization');
  }

  static Future<bool> startTerminalService() async {
    return await _channel.invokeMethod('startTerminalService');
  }

  static Future<bool> stopTerminalService() async {
    return await _channel.invokeMethod('stopTerminalService');
  }

  static Future<bool> isTerminalServiceRunning() async {
    return await _channel.invokeMethod('isTerminalServiceRunning');
  }

  static Stream<String> get eventStream async* {
    await for (final event in _eventChannel.receiveBroadcastStream()) {
      if (event is String) yield event;
    }
  }
}
