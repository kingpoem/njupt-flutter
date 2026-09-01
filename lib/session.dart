import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:njupt_flutter/credential_store.dart';
import 'package:njupt_flutter/src/rust/api/card.dart';
import 'package:njupt_flutter/src/rust/api/jwxt.dart';

class SessionController extends ChangeNotifier {
  static const _kUsername = 'njupt_username';
  static const _kOffCampus = 'njupt_off_campus';
  static const _kYear = 'njupt_year';
  static const _kTerm = 'njupt_term';
  static const _kStaySignedIn = 'njupt_stay_signed_in';

  SessionController({CredentialStore? credentials})
    : credentials = credentials ?? CredentialStore(),
      year = DateTime.now().month >= 9
          ? DateTime.now().year
          : DateTime.now().year - 1,
      term = DateTime.now().month >= 2 && DateTime.now().month < 9
          ? BridgeTerm.second
          : BridgeTerm.first;

  final CredentialStore credentials;

  JwxtHandle? jwxt;
  CardHandle? card;
  String? username;
  bool offCampus = false;
  bool loggingIn = false;
  /// 启动时尝试用本地账密恢复会话。
  bool restoring = true;
  String? lastError;
  int year;
  BridgeTerm term;

  bool get isLoggedIn => jwxt != null;

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
    notifyListeners();
  }

  /// 若上次登录未主动退出，则用缓存账密自动登录。
  Future<void> tryRestoreSession() async {
    restoring = true;
    lastError = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = username?.trim() ?? '';
      final password = credentials.passwordFor(user);
      // null = 升级前已登录过：有账密则自动恢复；显式退出后为 false
      final stay = prefs.getBool(_kStaySignedIn) ??
          (user.isNotEmpty && password != null && password.isNotEmpty);
      if (!stay || user.isEmpty || password == null || password.isEmpty) {
        return;
      }
      await login(
        username: user,
        password: password,
        offCampus: offCampus,
        fromRestore: true,
      );
    } finally {
      restoring = false;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStaySignedIn, false);
    notifyListeners();
    if (j != null) await clearJwxtCache(jwxt: j);
    if (c != null) await clearCardCache(card: c);
  }
}
