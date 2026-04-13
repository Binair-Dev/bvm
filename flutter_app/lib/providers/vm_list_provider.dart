import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class VmInfo {
  final String name;
  final DateTime createdAt;
  final String distro;
  final String size;
  final bool isRunning;
  final bool autoStart;

  VmInfo({
    required this.name,
    required this.createdAt,
    required this.distro,
    required this.size,
    this.isRunning = false,
    this.autoStart = false,
  });

  VmInfo copyWith({
    String? name,
    DateTime? createdAt,
    String? distro,
    String? size,
    bool? isRunning,
    bool? autoStart,
  }) {
    return VmInfo(
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      distro: distro ?? this.distro,
      size: size ?? this.size,
      isRunning: isRunning ?? this.isRunning,
      autoStart: autoStart ?? this.autoStart,
    );
  }
}

class VmListProvider extends ChangeNotifier {
  List<VmInfo> _vms = [];
  bool _isLoading = false;
  String? _error;

  List<VmInfo> get vms => List.unmodifiable(_vms);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await NativeBridge.vmList();
      _vms = list.map((m) {
        return VmInfo(
          name: m['name'] ?? '',
          createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
          distro: m['distro'] ?? '',
          size: m['size'] ?? '0 B',
          isRunning: m['isRunning'] == 'true',
          autoStart: m['autoStart'] == 'true',
        );
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteVm(String name) async {
    try {
      final ok = await NativeBridge.vmDelete(name);
      if (ok) {
        _vms.removeWhere((v) => v.name == name);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> startVm(String name) async {
    try {
      final ok = await NativeBridge.vmStart(name);
      if (ok) {
        final index = _vms.indexWhere((v) => v.name == name);
        if (index >= 0) {
          _vms[index] = _vms[index].copyWith(isRunning: true);
          notifyListeners();
        }
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopVm(String name) async {
    try {
      final ok = await NativeBridge.vmStop(name);
      if (ok) {
        final index = _vms.indexWhere((v) => v.name == name);
        if (index >= 0) {
          _vms[index] = _vms[index].copyWith(isRunning: false);
          notifyListeners();
        }
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setAutoStart(String name, bool autoStart) async {
    try {
      final ok = await NativeBridge.vmSetAutoStart(name, autoStart);
      if (ok) {
        final index = _vms.indexWhere((v) => v.name == name);
        if (index >= 0) {
          _vms[index] = _vms[index].copyWith(autoStart: autoStart);
          notifyListeners();
        }
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void updateVmState(String name, {bool? isRunning, bool? autoStart}) {
    final index = _vms.indexWhere((v) => v.name == name);
    if (index >= 0) {
      _vms[index] = _vms[index].copyWith(
        isRunning: isRunning,
        autoStart: autoStart,
      );
      notifyListeners();
    }
  }
}
