import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyAutoStart = 'auto_start_gateway';
  static const _keySetupComplete = 'setup_complete';
  static const _keyFirstRun = 'first_run';
  static const _keyLastAppVersion = 'last_app_version';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get autoStartGateway => _prefs.getBool(_keyAutoStart) ?? false;
  set autoStartGateway(bool value) => _prefs.setBool(_keyAutoStart, value);

  bool get setupComplete => _prefs.getBool(_keySetupComplete) ?? false;
  set setupComplete(bool value) => _prefs.setBool(_keySetupComplete, value);

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;
  set isFirstRun(bool value) => _prefs.setBool(_keyFirstRun, value);

  String? get lastAppVersion => _prefs.getString(_keyLastAppVersion);
  set lastAppVersion(String? value) {
    if (value != null) {
      _prefs.setString(_keyLastAppVersion, value);
    } else {
      _prefs.remove(_keyLastAppVersion);
    }
  }
}
