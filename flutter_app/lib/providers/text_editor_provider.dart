import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class TextEditorProvider extends ChangeNotifier {
  String _content = '';
  String _originalContent = '';
  String _fileName = '';
  String _filePath = '';
  String _vmName = '';
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String get content => _content;
  String get fileName => _fileName;
  String get filePath => _filePath;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  
  bool get hasUnsavedChanges => _content != _originalContent;

  Future<void> loadFile(String vmName, String filePath) async {
    _isLoading = true;
    _error = null;
    _vmName = vmName;
    _filePath = filePath;
    _fileName = filePath.split('/').last;
    notifyListeners();

    try {
      // Remove leading slash for the native method
      final relativePath = filePath.startsWith('/') ? filePath.substring(1) : filePath;
      final content = await NativeBridge.readRootfsFile(relativePath, vmName: vmName);
      _content = content;
      _originalContent = content;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load file: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateContent(String newContent) {
    _content = newContent;
    notifyListeners();
  }

  Future<bool> saveFile() async {
    if (!hasUnsavedChanges) return true;
    
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final relativePath = _filePath.startsWith('/') ? _filePath.substring(1) : _filePath;
      final success = await NativeBridge.writeRootfsFile(relativePath, _content, vmName: _vmName);
      if (success) {
        _originalContent = _content;
        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to save file';
        _isSaving = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to save file: $e';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _content = '';
    _originalContent = '';
    _fileName = '';
    _filePath = '';
    _vmName = '';
    _error = null;
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }
}
