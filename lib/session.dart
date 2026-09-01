import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:njupt_flutter/credential_store.dart';
import 'package:njupt_flutter/disk_cache.dart';
import 'package:njupt_flutter/src/rust/api/card.dart';
import 'package:njupt_flutter/src/rust/api/jwxt.dart';

class SessionController extends ChangeNotifier {
  static const _kUsername = 'njupt_username';
  static const _kOffCampus = 'njupt_off_campus';
  static const _kYear = 'njupt_year';
  static const _kTerm = 'njupt_term';
  static const _kStaySignedIn = 'njupt_stay_signed_in';

  SessionController({CredentialStore? credentials, DiskCache? diskCache})
    : credentials = credentials ?? CredentialStore(),
      diskCache = diskCache ?? DiskCache(),
      year = DateTime.now().month >= 9
          ? DateTime.now().year
          : DateTime.now().year - 1,
      term = DateTime.now().month >= 2 && DateTime.now().month < 9
          ? BridgeTerm.second
          : BridgeTerm.first;

  final CredentialStore credentials;
  final DiskCache diskCache;

  JwxtHandle? jwxt;
  CardHandle? card;
  String? username;
  bool offCampus = false;
  bool loggingIn = false;
  /// 后台自动登录进行中（主页已可先展示磁盘缓存）。
  bool signingIn = false;
  String? lastError;
  int year;
  BridgeTerm term;

  bool _wantsHome = false;
  Completer<void>? _onlineGate;

  bool get isLoggedIn => jwxt != null;

  /// 已登录，或具备自动登录条件（先看缓存再后台登录）。
  bool get showHome => isLoggedIn || _wantsHome;

  Future<void> get whenOnline {
    if (jwxt != null) return Future.value();
    return (_onlineGate ??= Completer<void>()).future;
  }

  void _openOnlineGate() {
    final gate = _onlineGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    _onlineGate = null;
  }

  Future<void> loadPrefs() async {
    await credentials.load();
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString(_kUsername);
    offCampus = prefs.getBool(_kOffCampus) ?? false;
    year = prefs.getInt(_kYear) ?? year;
    final termIdx = prefs.getInt(_kTerm);
    if (termIdx != null) {
      term = termIdx == 1 ? BridgeTerm.second : BridgeTerm.first;
    }

    final user = username?.trim() ?? '';
    final password = credentials.passwordFor(user);
    final stay = prefs.getBool(_kStaySignedIn) ??
        (user.isNotEmpty && password != null && password.isNotEmpty);
    if (stay && user.isNotEmpty && password != null && password.isNotEmpty) {
      _wantsHome = true;
      signingIn = true;
      _onlineGate ??= Completer<void>();
    }
    notifyListeners();
  }

  /// 立刻进入主页（若可自动登录），后台完成网络登录。
  Future<void> tryRestoreSession() async {
    lastError = null;
    final user = username?.trim() ?? '';
    final password = credentials.passwordFor(user);
    if (!_wantsHome || user.isEmpty || password == null || password.isEmpty) {
      _wantsHome = false;
      signingIn = false;
      _openOnlineGate();
      notifyListeners();
      return;
    }

    signingIn = true;
    _onlineGate ??= Completer<void>();
    notifyListeners();

    try {
      await login(
        username: user,
        password: password,
        offCampus: offCampus,
        fromRestore: true,
      );
    } finally {
      signingIn = false;
      _openOnlineGate();
      notifyListeners();
    }
  }

  Future<void> setPeriod({required int year, required BridgeTerm term}) async {
    this.year = year;
    this.term = term;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kYear, year);
    await prefs.setInt(_kTerm, term == BridgeTerm.second ? 1 : 0);
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
    required bool offCampus,
    bool fromRestore = false,
  }) async {
    if (!fromRestore) {
      loggingIn = true;
      lastError = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        offCampus
            ? loginOffCampus(username: username, password: password)
            : loginCampus(username: username, password: password),
        offCampus
            ? loginCardOffCampus(username: username, password: password)
            : loginCardCampus(username: username, password: password),
      ]);
      jwxt = results[0] as JwxtHandle;
      card = results[1] as CardHandle;
      this.username = username;
      this.offCampus = offCampus;
      _wantsHome = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUsername, username);
      await prefs.setBool(_kOffCampus, offCampus);
      await prefs.setBool(_kStaySignedIn, true);
      await credentials.savePassword(username, password);
      loggingIn = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e.toString();
      loggingIn = false;
      if (fromRestore) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kStaySignedIn, false);
        // 有磁盘缓存则继续留在主页只读；否则退回登录页
        final hasCache = await diskCache.hasAny(username);
        _wantsHome = hasCache;
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final j = jwxt;
    final c = card;
    jwxt = null;
    card = null;
    lastError = null;
    _wantsHome = false;
    signingIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStaySignedIn, false);
    _openOnlineGate();
    notifyListeners();
    if (j != null) await clearJwxtCache(jwxt: j);
    if (c != null) await clearCardCache(card: c);
  }

  static String scheduleKey(int year, BridgeTerm term) =>
      'schedule_${year}_${term.name}';

  static String gradesKey(int? year, BridgeTerm? term) =>
      'grades_${year ?? 'all'}_${term?.name ?? 'all'}';

  static String gradeDetailsKey(int? year, BridgeTerm? term) =>
      'grade_details_${year ?? 'all'}_${term?.name ?? 'all'}';

  static String examsKey(String kind, int? year, BridgeTerm? term) =>
      'exams_${kind}_${year ?? 'all'}_${term?.name ?? 'all'}';

  static String selectedKey(int? year, BridgeTerm? term) =>
      'selected_${year ?? 'all'}_${term?.name ?? 'all'}';

  static const profileKey = 'profile';
  static const cardBalanceKey = 'card_balance';
}
