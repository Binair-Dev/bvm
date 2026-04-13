import 'dart:async';
import 'package:flutter/material.dart';
import '../models/preset.dart';
import '../services/native_bridge.dart';

enum SetupStatus { idle, running, success, error }

class VmSetupProvider extends ChangeNotifier {
  SetupStatus _status = SetupStatus.idle;
  String _logText = '';
  String? _error;
  String _vmName = '';
  int _currentStep = 0;
  int _totalSteps = 0;
  String _currentStepLabel = '';

  SetupStatus get status => _status;
  String get logText => _logText;
  String? get error => _error;
  String get vmName => _vmName;
  int get currentStep => _currentStep;
  int get totalSteps => _totalSteps;
  String get currentStepLabel => _currentStepLabel;
  double get progress => _totalSteps > 0 ? _currentStep / _totalSteps : 0.0;

  Future<void> createVm(String name, {Preset? preset}) async {
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
    _currentStep = 0;
    _totalSteps = 1 + (preset?.commands.length ?? 0);
    _currentStepLabel = 'Creating VM rootfs...';
    notifyListeners();

    try {
      // Step 1: Create VM
      final ok = await NativeBridge.vmCreate(trimmed);
      if (!ok) {
        throw Exception('Native create returned false. The base rootfs may be missing.');
      }
      _currentStep = 1;
      _logText += '✓ VM rootfs created\n';
      notifyListeners();

      // Execute preset commands
      if (preset != null && preset.commands.isNotEmpty) {
        for (int i = 0; i < preset.commands.length; i++) {
          final cmd = preset.commands[i];
          _currentStep = 1 + i;
          _currentStepLabel = 'Running: ${cmd.length > 40 ? cmd.substring(0, 40) + "..." : cmd}';
          _logText += '> $cmd\n';
          notifyListeners();

          try {
            final output = await NativeBridge.runInProot(cmd, vmName: trimmed, timeout: 600);
            _logText += '$output\n';
          } catch (e) {
            _logText += 'Error: $e\n';
            // Continue with next commands but log the error
          }
          notifyListeners();
        }
      }

      _currentStep = _totalSteps;
      _currentStepLabel = 'Done!';
      _status = SetupStatus.success;
      _logText += '\n✓ VM "$trimmed" is ready!\n';
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
    _currentStep = 0;
    _totalSteps = 0;
    _currentStepLabel = '';
    notifyListeners();
  }
}
