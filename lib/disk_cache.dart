import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 教务/校园卡 JSON 磁盘缓存（按学号分目录，杀进程仍在）。
class DiskCache {
  Directory? _root;

  Future<Directory> _ensureRoot() async {
    if (_root != null) return _root!;
    final base = await getApplicationSupportDirectory();
    _root = Directory(p.join(base.path, 'njupt_api_cache'));
    if (!await _root!.exists()) {
      await _root!.create(recursive: true);
    }
    return _root!;
  }

  Future<File> _file(String username, String key) async {
    final root = await _ensureRoot();
    final safeUser = username.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final dir = Directory(p.join(root.path, safeUser));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, '$safeKey.json'));
  }

  /// 返回完整 envelope：`{"data":...,"from_cache":true}`
  Future<String?> readEnvelope(String username, String key) async {
    if (username.isEmpty || key.isEmpty) return null;
    final file = await _file(username, key);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return jsonEncode({
        'data': map['data'],
        'from_cache': true,
      });
    } catch (_) {
      return null;
    }
  }

  /// 写入网络返回的 envelope（保留 data，标记来源无关）。
  Future<void> writeEnvelope(String username, String key, String envelope) async {
    if (username.isEmpty || key.isEmpty) return;
    final map = jsonDecode(envelope) as Map<String, dynamic>;
    final file = await _file(username, key);
    await file.writeAsString(
      jsonEncode({
        'data': map['data'],
        'saved_at': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  Future<bool> hasAny(String username) async {
    if (username.isEmpty) return false;
    final root = await _ensureRoot();
    final safeUser = username.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final dir = Directory(p.join(root.path, safeUser));
    if (!await dir.exists()) return false;
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) return true;
    }
    return false;
  }
}
