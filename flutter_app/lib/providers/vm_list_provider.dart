import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class VmInfo {
  final String name;
  final DateTime createdAt;
  final String distro;
  final String size;

  VmInfo({
    required this.name,
    required this.createdAt,
    required this.distro,
    required this.size,
  });
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
}
