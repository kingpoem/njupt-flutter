import 'dart:async';

import 'package:flutter/material.dart';

import 'package:njupt_flutter/screens/home.dart';
import 'package:njupt_flutter/session.dart';
import 'package:njupt_flutter/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final session = SessionController();
  await session.loadPrefs();
  runApp(NjuptApp(session: session));
  unawaited(session.tryRestoreSession());
}

class NjuptApp extends StatelessWidget {
  const NjuptApp({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '南邮校园',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (session.restoring) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!session.isLoggedIn) {
            return LoginPage(session: session);
          }
          return HomeShell(session: session);
        },
      ),
    );
  }
}
