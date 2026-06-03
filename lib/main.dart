import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/camera_screen.dart';

// バックグラウンドで受信した通知を処理するトップレベル関数
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // バックグラウンド通知ハンドラを登録
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 縦画面固定
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // カメラ一覧を起動時に取得
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

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
      home: HomeScreen(cameras: cameras),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final messaging = FirebaseMessaging.instance;

    // 通知許可リクエスト（iOS / Android 13+）
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM トークンを取得（後でサーバーに登録する）
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');

    // フォアグラウンドで通知を受信したときの処理
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.notification?.title}');
      // TODO: 通知バナーを表示し、撮影画面に遷移する
    });

    // 通知タップでアプリが起動したときの処理
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped: ${message.notification?.title}');
      // TODO: 撮影画面に遷移する
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'OneShot',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '一発撮り・インポート禁止',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('撮影を開始する'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
