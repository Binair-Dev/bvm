import 'dart:async';
import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

enum SetupStatus { idle, running, success, error }

class VmSetupProvider extends ChangeNotifier {
  SetupStatus _status = SetupStatus.idle;
  String _logText = '';
  String? _error;
  String _vmName = '';

  SetupStatus get status => _status;
  String get logText => _logText;
  String? get error => _error;
  String get vmName => _vmName;

  StreamSubscription<String>? _logSubscription;

  Future<void> createVm(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _error = 'VM name cannot be empty';
      notifyListeners();
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      _error = 'Invalid VM name. Use only letters, numbers, underscores, and hyphens.';
      notifyListeners();
      return;
    }
    if (trimmed.toLowerCase() == 'ubuntu') {
      _error = '"ubuntu" is reserved for the base rootfs. Choose another name.';
      notifyListeners();
      return;
    }

    try {
      final existing = await NativeBridge.vmList();
      final alreadyExists = existing.any((vm) => (vm['name'] ?? '').toString().toLowerCase() == trimmed.toLowerCase());
      if (alreadyExists) {
        _error = 'A VM named "$trimmed" already exists.';
        _status = SetupStatus.error;
        notifyListeners();
        return;
      }
    } catch (e) {
      _error = 'Failed to check existing VMs: $e';
      _status = SetupStatus.error;
      notifyListeners();
      return;
    }

    _vmName = trimmed;
    _status = SetupStatus.running;
    _logText = '';
    _error = null;
    notifyListeners();

    try {
      final ok = await NativeBridge.vmCreate(trimmed);
      if (!ok) {
        throw Exception('Native create returned false. The base rootfs may be missing.');
      }
      _status = SetupStatus.success;
    } catch (e) {
      _status = SetupStatus.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  void appendLog(String line) {
    _logText += '$line\n';
    notifyListeners();
  }

  void reset() {
    _status = SetupStatus.idle;
    _logText = '';
    _error = null;
    _vmName = '';
    _logSubscription?.cancel();
    notifyListeners();
  }
}
