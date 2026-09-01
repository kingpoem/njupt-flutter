import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 仅使用系统 Keychain / Keystore（flutter_secure_storage），不做明文兜底。
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // 传统 Keychain：不依赖 Data Protection Keychain 的额外 entitlement
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
          );

  static const _kMap = 'njupt_password_map';

  final FlutterSecureStorage _storage;
  Map<String, String> _passwords = {};

  Future<void> load() async {
    final raw = await _storage.read(key: _kMap);
    _passwords = raw == null || raw.isEmpty ? {} : _decode(raw);
  }

  Map<String, String> _decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in map.entries)
        if (e.key.trim().isNotEmpty &&
            e.value is String &&
            (e.value as String).isNotEmpty)
          e.key.trim(): e.value as String,
    };
  }

  String? passwordFor(String username) {
    final key = username.trim();
    if (key.isEmpty) return null;
    final p = _passwords[key];
    if (p == null || p.isEmpty) return null;
    return p;
  }

  /// 登录成功后调用：按学号覆盖保存密码。
  Future<void> savePassword(String username, String password) async {
    final key = username.trim();
    if (key.isEmpty || password.isEmpty) return;

    final next = Map<String, String>.from(_passwords)..[key] = password;
    await _storage.write(key: _kMap, value: jsonEncode(next));
    _passwords = next;
  }
}
