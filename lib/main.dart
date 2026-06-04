import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/shot_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await FirebaseMessaging.instance.requestPermission();
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  try {
    await availableCameras();
  } catch (e) {
    debugPrint('Camera not available: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ShotState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneShot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }
          if (snapshot.hasData) {
            // ログイン後にShotStateを初期化
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<ShotState>().initialize();
            });
            return const MainShell();
          }
          // ログアウト時にリセット
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<ShotState>().reset();
          });
          return const LoginScreen();
        },
      ),
    );
  }
}
