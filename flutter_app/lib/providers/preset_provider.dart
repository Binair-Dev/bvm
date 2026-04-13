import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/preset.dart';

class PresetProvider extends ChangeNotifier {
  List<Preset> _presets = [];
  bool _isLoading = true;

  List<Preset> get presets => List.unmodifiable(_presets);
  List<Preset> get builtInPresets => _presets.where((p) => p.isBuiltIn).toList();
  List<Preset> get customPresets => _presets.where((p) => !p.isBuiltIn).toList();
  bool get isLoading => _isLoading;

  PresetProvider() {
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    _isLoading = true;
    notifyListeners();

    final custom = await _loadCustomPresets();
    _presets = [...Preset.builtIn, ...custom];
    _isLoading = false;
    notifyListeners();
  }

  Future<List<Preset>> _loadCustomPresets() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_presets.json');
      if (!file.existsSync()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list.map((e) => Preset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading custom presets: $e');
      return [];
    }
  }

  Future<void> _saveCustomPresets() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_presets.json');
      final custom = customPresets.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(custom));
    } catch (e) {
      debugPrint('Error saving custom presets: $e');
    }
  }

  Future<void> addCustomPreset(Preset preset) async {
    _presets.add(preset);
    await _saveCustomPresets();
    notifyListeners();
  }

  Future<void> updateCustomPreset(String id, Preset updated) async {
    final index = _presets.indexWhere((p) => p.id == id && !p.isBuiltIn);
    if (index >= 0) {
      _presets[index] = updated;
      await _saveCustomPresets();
      notifyListeners();
    }
  }

  Future<void> deleteCustomPreset(String id) async {
    _presets.removeWhere((p) => p.id == id && !p.isBuiltIn);
    await _saveCustomPresets();
    notifyListeners();
  }

  Preset? getPresetById(String id) {
    try {
      return _presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String exportPresetToJson(Preset preset) {
    return const JsonEncoder.withIndent('  ').convert(preset.toJson());
  }

  Future<Preset?> importPresetFromJson(String json) async {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final preset = Preset.fromJson(map);
      final newPreset = preset.copyWith(
        id: const Uuid().v4(),
        isBuiltIn: false,
      );
      await addCustomPreset(newPreset);
      return newPreset;
    } catch (e) {
      debugPrint('Error importing preset: $e');
      return null;
    }
  }
}
