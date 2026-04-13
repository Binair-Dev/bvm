import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';

class BackupProgress {
  final double percent;
  final String message;
  final bool isComplete;
  final String? error;

  BackupProgress({
    this.percent = 0,
    this.message = '',
    this.isComplete = false,
    this.error,
  });
}

class BackupProvider extends ChangeNotifier {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _error;
  String? _lastMessage;
  BackupProgress _progress = BackupProgress();

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  bool get isBusy => _isExporting || _isImporting;
  String? get error => _error;
  String? get lastMessage => _lastMessage;
  BackupProgress get progress => _progress;

  Future<bool> exportVm(String vmName, Function(BackupProgress) onProgress) async {
    _isExporting = true;
    _error = null;
    _lastMessage = null;
    _progress = BackupProgress();
    notifyListeners();

    final eventChannel = EventChannel('com.bvm.mobile/backup_events');
    late StreamSubscription subscription;

    subscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        final map = Map<String, dynamic>.from(event);
        final type = map['type'] as String?;
        
        if (type == 'progress') {
          final current = (map['current'] as num?)?.toDouble() ?? 0;
          final total = (map['total'] as num?)?.toDouble() ?? 1;
          final message = map['message'] as String? ?? '';
          _progress = BackupProgress(
            percent: total > 0 ? (current / total * 100).clamp(0, 100) : 0,
            message: message,
          );
          onProgress(_progress);
          notifyListeners();
        } else if (type == 'complete') {
          _progress = BackupProgress(percent: 100, message: 'Done!', isComplete: true);
          onProgress(_progress);
          notifyListeners();
        } else if (type == 'error') {
          _progress = BackupProgress(
            percent: 0,
            message: '',
            error: map['message'] as String? ?? 'Unknown error',
          );
          onProgress(_progress);
          notifyListeners();
        }
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    try {
      final result = await NativeBridge.exportVm(vmName);
      _lastMessage = 'Backup saved';
      _isExporting = false;
      await subscription.cancel();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isExporting = false;
      await subscription.cancel();
      notifyListeners();
      return false;
    }
  }

  Future<String?> importVm(Function(BackupProgress) onProgress) async {
    _isImporting = true;
    _error = null;
    _lastMessage = null;
    _progress = BackupProgress();
    notifyListeners();

    final eventChannel = EventChannel('com.bvm.mobile/backup_events');
    late StreamSubscription subscription;

    subscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        final map = Map<String, dynamic>.from(event);
        final type = map['type'] as String?;
        
        if (type == 'progress') {
          final current = (map['current'] as num?)?.toDouble() ?? 0;
          final total = (map['total'] as num?)?.toDouble() ?? 100;
          final message = map['message'] as String? ?? '';
          _progress = BackupProgress(
            percent: total > 0 ? (current / total * 100).clamp(0, 100) : 0,
            message: message,
          );
          onProgress(_progress);
          notifyListeners();
        } else if (type == 'complete') {
          _progress = BackupProgress(percent: 100, message: 'Done!', isComplete: true);
          onProgress(_progress);
          notifyListeners();
        } else if (type == 'error') {
          _progress = BackupProgress(
            percent: 0,
            message: '',
            error: map['message'] as String? ?? 'Unknown error',
          );
          onProgress(_progress);
          notifyListeners();
        }
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    try {
      final result = await NativeBridge.importVm();
      final vmName = result['vmName'] as String?;
      _lastMessage = 'VM imported as $vmName';
      _isImporting = false;
      await subscription.cancel();
      notifyListeners();
      return vmName;
    } catch (e) {
      _error = e.toString();
      _isImporting = false;
      await subscription.cancel();
      notifyListeners();
      return null;
    }
  }

  void clearMessage() {
    _lastMessage = null;
    _error = null;
    _progress = BackupProgress();
    notifyListeners();
  }
}
