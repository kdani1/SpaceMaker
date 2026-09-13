import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacemaker/entitlement.dart';

class UserAccount {
  UserAccount({
    required this.id,
    required this.email,
    required this.name,
    required this.isPlus,
    required this.plan,
    required this.freeEmptiesLeft,
  });

  final int id;
  final String email;
  final String name;
  final bool isPlus;
  final String? plan;
  final int freeEmptiesLeft;

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        name: json['name'] as String,
        isPlus: json['isPlus'] == true,
        plan: json['plan'] as String?,
        freeEmptiesLeft: (json['freeEmptiesLeft'] as num?)?.toInt() ?? 0,
      );
}

class Api {
  Api._();
  static final Api instance = Api._();

  static const _keyUrl = 'api_url';
  static const _keyToken = 'token';
  static const _keyOffline = 'offline';
  static const defaultUrl = 'http://192.168.0.249:51810';

  String baseUrl = defaultUrl;
  String? token;
  UserAccount? user;

  /// When true the app runs entirely on device: no server is contacted and
  /// subscription state lives in shared preferences.
  bool offline = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_keyUrl) ?? defaultUrl;
    offline = prefs.getBool(_keyOffline) ?? false;
    if (offline) {
      user = _deviceUser();
      return;
    }
    token = prefs.getString(_keyToken);
    if (token != null) {
      try {
        user = await me();
        await Entitlement.instance.syncFromAccount(accountPlus: user!.isPlus, accountPlan: user!.plan);
      } catch (_) {
        token = null;
        user = null;
        await prefs.remove(_keyToken);
      }
    }
  }

  UserAccount _deviceUser() {
    final plus = Entitlement.instance.isPlus;
    return UserAccount(
      id: user?.id ?? 0,
      email: user?.email ?? 'offline@spacemaker.app',
      name: user?.name ?? 'You',
      isPlus: plus,
      plan: Entitlement.instance.plan,
      freeEmptiesLeft: plus ? 999 : Entitlement.instance.remaining,
    );
  }

  Future<UserAccount> continueOffline({bool plus = false}) async {
    final prefs = await SharedPreferences.getInstance();
    offline = true;
    token = null;
    await prefs.setBool(_keyOffline, true);
    await prefs.remove(_keyToken);
    if (plus) await Entitlement.instance.activate(Entitlement.instance.plan ?? 'yearly');
    user = _deviceUser();
    return user!;
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, baseUrl);
  }

  Future<void> _saveToken(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, value);
  }

  Future<void> logout() async {
    token = null;
    user = null;
    offline = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyOffline);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Without this an unreachable server leaves the UI spinning until the OS
  /// gives up, which can take minutes.
  static const _timeout = Duration(seconds: 8);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw Exception('Server did not answer at $baseUrl. Use offline mode or check the address.');
    } on SocketException {
      throw Exception('Cannot reach $baseUrl. Use offline mode or check the address.');
    }
  }

  Future<UserAccount> login(String email, String password) async {
    final res = await _guard(() => http.post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        ));
    return _auth(res);
  }

  Future<UserAccount> register(String name, String email, String password) async {
    final res = await _guard(() => http.post(
          Uri.parse('$baseUrl/api/auth/register'),
          headers: _headers,
          body: jsonEncode({'name': name, 'email': email, 'password': password}),
        ));
    return _auth(res);
  }

  Future<UserAccount> me() async {
    final res = await _guard(() => http.get(Uri.parse('$baseUrl/api/me'), headers: _headers));
    if (res.statusCode != 200) {
      throw Exception(_error(res, 'Session expired'));
    }
    user = UserAccount.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    return user!;
  }

  Future<UserAccount> activate(String plan) async {
    await Entitlement.instance.activate(plan);
    if (!offline && token != null) {
      try {
        final res = await _guard(() => http.post(
              Uri.parse('$baseUrl/api/subscription/activate'),
              headers: _headers,
              body: jsonEncode({'plan': plan}),
            ));
        if (res.statusCode == 200) {
          user = UserAccount.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
          return user!;
        }
      } catch (_) {}
    }
    user = _deviceUser();
    return user!;
  }

  Future<bool> consumeEmpty() async => true;

  Future<UserAccount> _auth(http.Response res) async {
    if (res.statusCode != 200) {
      throw Exception(_error(res, 'Could not sign in'));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    offline = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOffline, false);
    await _saveToken(body['token'] as String);
    user = UserAccount.fromJson(body['user'] as Map<String, dynamic>);
    await Entitlement.instance.syncFromAccount(accountPlus: user!.isPlus, accountPlan: user!.plan);
    return user!;
  }

  String _error(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) return body['error'] as String;
    } catch (_) {}
    return fallback;
  }
}
