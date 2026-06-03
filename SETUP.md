# 開発環境セットアップ手順

このドキュメントは新しくプロジェクトに参加するメンバー向けです。

---

## 1. 前提ツールのインストール

| ツール | 用途 |
|--------|------|
| Flutter SDK | アプリ開発 |
| Node.js (LTS) | Firebase CLI の実行 |
| Firebase CLI | Firebase プロジェクトの管理 |
| FlutterFire CLI | Firebase × Flutter の自動設定 |

```bash
# Firebase CLI
npm install -g firebase-tools

# FlutterFire CLI
dart pub global activate flutterfire_cli
```

---

## 2. Firebase への接続（全員が必要）

Firebaseプロジェクトに接続し、`google-services.json` と `firebase_options.dart` を
自動生成するコマンドです。**一人ひとりが自分のPCで実行してください。**

```bash
# Googleアカウントでログイン（ブラウザが開きます）
firebase login

# プロジェクトルートで実行（flutter_application_1/ の中で）
flutterfire configure
```

`flutterfire configure` を実行すると：
- `lib/firebase_options.dart` が上書き生成されます ✅
- `android/app/google-services.json` が生成されます ✅
- `ios/Runner/GoogleService-Info.plist` が生成されます ✅

> **注意**: `google-services.json` と `GoogleService-Info.plist` と `firebase_options.dart` は
> `.gitignore` により Git 管理対象外です。各自で生成してください。

---

## 3. パッケージのインストール

```bash
flutter pub get
```

---

## 4. 動作確認

```bash
flutter run
```

---

## Firebase プロジェクト情報

（管理者がここにプロジェクトIDを記入してください）

- **Firebase プロジェクトID**: `your-project-id`
- **Firebase コンソール**: https://console.firebase.google.com/project/your-project-id

---

## 使用中の Firebase サービス

| サービス | 用途 |
|----------|------|
| Firebase Authentication | ユーザー認証 |
| Cloud Firestore | 投稿データの管理 |
| Firebase Storage | 動画ファイルの保存 |
| Firebase Cloud Messaging (FCM) | 1日1回の一斉プッシュ通知 |
| Cloud Functions | 通知スケジュールの制御（サーバーサイド） |
