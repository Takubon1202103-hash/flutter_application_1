// IMPORTANT: このファイルは `flutterfire configure` コマンドで自動生成されます。
// 手動で編集しないでください。下記の手順でセットアップを完了させると、
// このファイルは正しい内容に自動的に書き換えられます。
//
// セットアップ手順:
//   1. firebase login
//   2. flutterfire configure
//
// 詳しくは SETUP.md を参照してください。

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnimplementedError(
      '\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      'Firebase の初期設定が完了していません。\n'
      '\n'
      'ターミナルで以下を順番に実行してください:\n'
      '  1) dart pub global activate flutterfire_cli\n'
      '  2) firebase login\n'
      '  3) flutterfire configure\n'
      '\n'
      '詳しくは SETUP.md を参照してください。\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n',
    );
  }
}
