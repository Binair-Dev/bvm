import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final String permissions;
  final int lastModified;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.permissions,
    required this.lastModified,
  });

  factory FileItem.fromMap(Map<dynamic, dynamic> map) {
    return FileItem(
      name: map['name'] as String,
      path: map['path'] as String,
      isDirectory: map['isDirectory'] as bool,
      size: (map['size'] as num).toInt(),
      permissions: map['permissions'] as String,
      lastModified: (map['lastModified'] as num).toInt(),
    );
  }

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class FileSharingProvider extends ChangeNotifier {
  List<FileItem> _sharedFiles = [];
  List<FileItem> _vmFiles = [];
  bool _isLoading = false;
  String? _error;
  String _currentPath = '/';

  List<FileItem> get sharedFiles => _sharedFiles;
  List<FileItem> get vmFiles => _vmFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentPath => _currentPath;

  Future<void> setupSharedDir(String vmName) async {
    try {
      await NativeBridge.setupSharedDir(vmName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadSharedFiles(String vmName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final files = await NativeBridge.listSharedFiles(vmName);
      _sharedFiles = files.map((f) => FileItem.fromMap(f)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVmDirectory(String vmName, String path) async {
    _isLoading = true;
    _error = null;
    _currentPath = path;
    notifyListeners();

    try {
      final files = await NativeBridge.listVmDirectory(vmName, path);
      _vmFiles = files.map((f) => FileItem.fromMap(f)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadFile(String vmName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await NativeBridge.uploadFileToVm(vmName);
      _isLoading = false;
      await loadSharedFiles(vmName);
      notifyListeners();
      return result['success'] as bool;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> downloadFile(String vmPath, String suggestedName, bool isDirectory) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await NativeBridge.downloadFileFromVm(vmPath, suggestedName, isDirectory);
      _isLoading = false;
      notifyListeners();
      return result['success'] as bool;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
