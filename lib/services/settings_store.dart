import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _baseUrlKey = 'server_base_url';
  static const _tokenKey = 'api_token';
  static const _createFlowKey = 'create_flow';

  static const createFlowPreview = 'preview';
  static const createFlowDirect = 'direct';

  String baseUrl = 'http://10.0.2.2:8080';
  String token = '';
  String createFlow = createFlowPreview;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey) ?? baseUrl;
    token = prefs.getString(_tokenKey) ?? '';
    createFlow = prefs.getString(_createFlowKey) ?? createFlowPreview;
  }

  Future<void> save({
    required String baseUrl,
    required String token,
    String? createFlow,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl.trim());
    await prefs.setString(_tokenKey, token.trim());
    this.baseUrl = baseUrl.trim();
    this.token = token.trim();
    if (createFlow != null) {
      await prefs.setString(_createFlowKey, createFlow);
      this.createFlow = createFlow;
    }
  }
}