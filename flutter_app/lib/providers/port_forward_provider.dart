import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class PortForward {
  final String id;
  final String vmName;
  final int vmPort;
  final int hostPort;
  final String bindAddress;

  PortForward({
    required this.id,
    required this.vmName,
    required this.vmPort,
    required this.hostPort,
    required this.bindAddress,
  });

  String get url {
    if (bindAddress == '0.0.0.0') {
      return 'http://<local-ip>:$hostPort';
    }
    return 'http://127.0.0.1:$hostPort';
  }
}

class PortForwardProvider extends ChangeNotifier {
  List<PortForward> _forwards = [];
  bool _isLoading = false;
  String? _error;
  String _localIp = '';

  List<PortForward> get forwards => List.unmodifiable(_forwards);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get localIp => _localIp;

  Future<void> loadForwards() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await NativeBridge.listPortForwards();
      _forwards = list.map((m) => PortForward(
        id: m['id'] ?? '',
        vmName: m['vmName'] ?? '',
        vmPort: m['vmPort'] ?? 0,
        hostPort: m['hostPort'] ?? 0,
        bindAddress: m['bindAddress'] ?? '127.0.0.1',
      )).toList();
      _localIp = await NativeBridge.getLocalIpAddress();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<PortForward> forwardsForVm(String vmName) {
    return _forwards.where((f) => f.vmName == vmName).toList();
  }

  Future<bool> addForward({
    required String vmName,
    required int vmPort,
    required int hostPort,
    bool exposeOnNetwork = false,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final bindAddress = exposeOnNetwork ? '0.0.0.0' : '127.0.0.1';
      final result = await NativeBridge.startPortForward(
        vmName: vmName,
        vmPort: vmPort,
        hostPort: hostPort,
        bindAddress: bindAddress,
      );
      final forward = PortForward(
        id: result['id'] ?? '',
        vmName: result['vmName'] ?? vmName,
        vmPort: result['vmPort'] ?? vmPort,
        hostPort: result['hostPort'] ?? hostPort,
        bindAddress: result['bindAddress'] ?? bindAddress,
      );
      _forwards.add(forward);
      _localIp = await NativeBridge.getLocalIpAddress();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeForward(String id) async {
    try {
      final ok = await NativeBridge.stopPortForward(id);
      if (ok) {
        _forwards.removeWhere((f) => f.id == id);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  String resolveUrl(PortForward forward) {
    if (forward.bindAddress == '0.0.0.0' && _localIp.isNotEmpty) {
      return 'http://$_localIp:${forward.hostPort}';
    }
    return 'http://127.0.0.1:${forward.hostPort}';
  }
}
