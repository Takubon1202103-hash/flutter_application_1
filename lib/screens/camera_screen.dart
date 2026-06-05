import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/location_service.dart';
import '../services/post_service.dart';
import '../services/shot_state.dart';
import '../utils/video_filters.dart';

const int kMaxRecordingSeconds = 60;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isSwitching = false;
  int _selectedCameraIndex = 0;

  Timer? _recordingTimer;
  int _remainingSeconds = kMaxRecordingSeconds;

  XFile? _recordedVideo;
  VideoPlayerController? _previewController;
  bool _isUploading = false;

  // デュアルカメラモード
  bool _dualMode = false;
  XFile? _backVideo;
  XFile? _frontVideo;
  bool _recordingFront = false;

  // 写真/動画モード
  bool _isPhotoMode = false;
  XFile? _capturedPhoto;

  // 編集
  int _filterIndex = 0;
  int _effectIndex = 0; // 0=なし, 1=キラキラ, 2=光, 3=虹色
  int _mergeLayoutIndex = 0; // 0=上下, 1=左右, 2=PiP
  int _transitionIndex = 0; // 0=なし, 1=フェード, 2=スライド, 3=ズーム
  int _musicIndex = 0; // 0=なし, 1=Upbeat, 2=Chill, 3=Dramatic
  final _captionController = TextEditingController();

  // 投稿制限
  int _postLimit = 6;
  bool _isPenalized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPostLimit();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _controller?.dispose();
    _previewController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _setupCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    await _controller?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isSwitching = false;
      });
    } catch (e) {
      debugPrint('Camera setup error: $e');
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isRecording) {
      return;
    }
    try {
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _remainingSeconds = kMaxRecordingSeconds;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _remainingSeconds--);
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final photo = await _controller!.takePicture();

      // デュアルモード: バック撮影完了 → フロントへ
      if (_dualMode && !_recordingFront) {
        setState(() {
          _backVideo = photo; // 写真をバック用に保存
          _recordingFront = true;
          _isInitialized = false;
        });

        // フロントカメラに切替
        final frontIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (frontIndex == -1) {
          // フロントカメラなければそのまま完了
          setState(() {
            _recordedVideo = photo;
            _recordingFront = false;
          });
          if (mounted) _showPhotoPreview();
          return;
        }

        _selectedCameraIndex = frontIndex;
        await _setupCamera(_cameras[frontIndex]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('フロントカメラで自撮り写真を撮影してください'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // デュアルモード: フロント撮影完了
      if (_dualMode && _recordingFront) {
        setState(() {
          _frontVideo = photo; // 写真をフロント用に保存
          _recordingFront = false;
        });
        // バック写真をプレビューとして使う
        if (_backVideo != null) {
          setState(() => _recordedVideo = _backVideo);
        }
        if (mounted) _showPhotoPreview();
        return;
      }

      // 通常モード
      setState(() {
        _recordedVideo = photo;
      });
      if (mounted) _showPhotoPreview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写真撮影に失敗しました: $e')),
        );
      }
    }
  }

  void _showPhotoPreview() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: Image.file(
                File(_capturedPhoto!.path),
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _capturedPhoto = null);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('再撮影'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _usePhoto();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('使用する'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _usePhoto() async {
    if (_capturedPhoto == null) return;
    // 写真をビデオファイルとして扱う（後処理用）
    setState(() {
      _recordedVideo = _capturedPhoto;
      _capturedPhoto = null;
    });
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecording) return;
    _recordingTimer?.cancel();

    try {
      final file = await controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _remainingSeconds = kMaxRecordingSeconds;
      });

      // デュアルモード: バック録画完了 → フロントへ
      if (_dualMode && !_recordingFront) {
        await _switchToFrontForDual(file);
        return;
      }

      // デュアルモード: フロント録画完了
      if (_dualMode && _recordingFront) {
        _frontVideo = file;
        setState(() => _recordingFront = false);
        // バック動画をプレビューとして使う
        if (_backVideo != null) {
          await _setupPreview(_backVideo!);
        }
        return;
      }

      // 通常モード
      await _setupPreview(file);
    } catch (e) {
      debugPrint('Stop recording error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isSwitching) return;
    if (_isRecording) await _stopRecording();
    setState(() {
      _isInitialized = false;
      _isSwitching = true;
    });
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _uploadAndPost() async {
    if (_recordedVideo == null) return;
    setState(() => _isUploading = true);
    try {
      final shotState = context.read<ShotState>();
      final isLate = shotState.calculateIsLate(DateTime.now());
      final locationName = await LocationService.getCurrentLocationName();
      final now = DateTime.now();

      final caption = _captionController.text.trim();
      final filterName = _filterIndex > 0
          ? kVideoFilters[_filterIndex].name
          : null;

      // 通知時刻との比較
      await _checkNotificationTiming(now);

      // デュアル撮影時は FFmpeg で結合
      File? uploadFile = File(_recordedVideo!.path);
      if (_backVideo != null && _frontVideo != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('動画を結合中...')),
          );
        }
        final mergedFile = await _mergeVideoAndPhoto();
        if (mergedFile != null) {
          uploadFile = mergedFile;
        }
      }

      await PostService.uploadPost(
        uploadFile,
        isLate: isLate,
        frontVideoFile: null, // 既に結合済み
        locationName: locationName,
        caption: caption.isNotEmpty ? caption : null,
        filterName: filterName,
      );

      if (mounted) {
        shotState.markPosted(now);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  Future<File?> _mergeVideoAndPhoto() async {
    if (_backVideo == null || _frontVideo == null) return null;

    try {
      final tmpDir = Directory.systemTemp;
      final mergedFile = File('${tmpDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4');

      final backVideoPath = _backVideo!.path;
      final frontImagePath = _frontVideo!.path;

      // トランジションフィルター構築
      String transitionFilter = '';
      if (_transitionIndex == 1) {
        // フェード効果
        transitionFilter = ',fade=t=out:st=2:d=0.5';
      } else if (_transitionIndex == 2) {
        // スライド効果
        transitionFilter = ',hflip';
      } else if (_transitionIndex == 3) {
        // ズーム効果
        transitionFilter = ',scale=trunc(iw/2):trunc(ih/2):flags=lanczos,scale=iw:ih';
      }

      // レイアウトに応じた FFmpeg コマンド構築
      String ffmpegCommand;

      if (_mergeLayoutIndex == 0) {
        // 上下配置
        ffmpegCommand = '-i "$backVideoPath" -i "$frontImagePath" '
            '-filter_complex "[0:v]scale=1080:1920[back];[1:v]scale=1080:960[front];'
            '[back][front]vstack=inputs=2$transitionFilter[out]" '
            '-map "[out]" -map 0:a -c:v libx264 -preset fast -c:a aac -y "${mergedFile.path}"';
      } else if (_mergeLayoutIndex == 1) {
        // 左右配置
        ffmpegCommand = '-i "$backVideoPath" -i "$frontImagePath" '
            '-filter_complex "[0:v]scale=540:1920[back];[1:v]scale=540:1920[front];'
            '[back][front]hstack=inputs=2$transitionFilter[out]" '
            '-map "[out]" -map 0:a -c:v libx264 -preset fast -c:a aac -y "${mergedFile.path}"';
      } else {
        // PiP（Picture-in-Picture）配置
        ffmpegCommand = '-i "$backVideoPath" -i "$frontImagePath" '
            '-filter_complex "[0:v]scale=1080:1920[back];[1:v]scale=270:480[front];'
            '[back][front]overlay=x=805:y=1440$transitionFilter[out]" '
            '-map "[out]" -map 0:a -c:v libx264 -preset fast -c:a aac -y "${mergedFile.path}"';
      }

      // FFmpeg 実行
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('動画・写真結合成功: ${mergedFile.path}');
        return mergedFile;
      } else {
        debugPrint('FFmpeg エラー: ${await session.getOutput()}');
        return null;
      }
    } catch (e) {
      debugPrint('動画・写真結合失敗: $e');
      return null;
    }
  }

  Future<void> _checkNotificationTiming(DateTime postedTime) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = '${postedTime.year}-${postedTime.month.toString().padLeft(2, '0')}-${postedTime.day.toString().padLeft(2, '0')}';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(dateKey)
        .get();

    if (!doc.exists) return;

    final sentAtList = (doc['sentAt'] as List?)?.cast<Timestamp>() ?? [];
    if (sentAtList.isEmpty) return;

    // 最後の通知時刻を確認
    final lastNotification = sentAtList.last.toDate();
    final diffMinutes = postedTime.difference(lastNotification).inMinutes;

    // 10分以内か判定
    final isOnTime = diffMinutes <= 10;

    // Firestore に記録
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(dateKey)
        .update({
          'postedAt': postedTime,
          'isOnTime': isOnTime,
        });

    // ペナルティ判定
    if (!isOnTime) {
      await _applyPenalty(user.uid);
    }
  }

  Future<void> _applyPenalty(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isPenalized': true,
      'postLimit': 3,
      'penaltyExpireAt': DateTime.now().add(const Duration(hours: 24)),
    });
  }

  Future<void> _loadPostLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _postLimit = doc['postLimit'] as int? ?? 6;
          _isPenalized = doc['isPenalized'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('投稿制限読み込みエラー: $e');
    }
  }

  // デュアルモード: バック録画完了後にフロントへ自動切替
  Future<void> _switchToFrontForDual(XFile backFile) async {
    setState(() {
      _backVideo = backFile;
      _recordingFront = true;
      _isInitialized = false;
      _isSwitching = true;
    });

    // フロントカメラに切替
    final frontIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (frontIndex == -1) {
      // フロントカメラなければそのまま完了
      setState(() {
        _recordedVideo = backFile;
        _recordingFront = false;
      });
      await _setupPreview(backFile);
      return;
    }

    _selectedCameraIndex = frontIndex;
    await _setupCamera(_cameras[frontIndex]);

    // フロントカメラの初期化完了後、自動で録画開始
    if (mounted && _controller != null && _controller!.value.isInitialized) {
      await _startRecording();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('フロントカメラで自撮りを撮影中'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setupPreview(XFile file) async {
    await _previewController?.dispose();
    final preview = VideoPlayerController.file(File(file.path));
    await preview.initialize();
    if (!mounted) return;
    setState(() {
      _recordedVideo = file;
      _previewController = preview;
    });
    await preview.setLooping(true);
    await preview.play();
  }

  Future<void> _retake() async {
    await _previewController?.dispose();
    setState(() {
      _recordedVideo = null;
      _previewController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recordedVideo != null) {
      return _buildPreviewScreen();
    }
    return _buildCameraScreen();
  }

  // ───────────────────────────────────────────────
  // カメラ撮影画面
  // ───────────────────────────────────────────────
  Widget _buildCameraScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // カメラプレビュー（カメラロールは一切開かない）
            if (_isInitialized && _controller != null)
              Center(
                child: Builder(
                  builder: (context) {
                    final ar = _controller!.value.aspectRatio;
                    // Android cameras return landscape ratio; invert for portrait
                    final previewAr = ar > 1.0 ? 1.0 / ar : ar;
                    return AspectRatio(
                      aspectRatio: previewAr,
                      child: CameraPreview(_controller!),
                    );
                  },
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 上部バー
            Positioned(
              top: 16,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // 写真/動画切り替え
                  if (!_isRecording && !_recordingFront)
                    GestureDetector(
                      onTap: () => setState(() => _isPhotoMode = !_isPhotoMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _isPhotoMode ? '📷 写真' : '🎥 動画',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!_isRecording) ...[
                    // デュアルモードトグル
                    GestureDetector(
                      onTap: () => setState(() => _dualMode = !_dualMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _dualMode ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.switch_camera,
                                color: _dualMode ? Colors.black : Colors.white,
                                size: 16),
                            const SizedBox(width: 4),
                            Text('デュアル',
                                style: TextStyle(
                                  color: _dualMode ? Colors.black : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                      ),
                    ),
                    if (_cameras.length > 1)
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                        onPressed: _switchCamera,
                      ),
                  ],
                ],
              ),
            ),
            // デュアルモード録画状態表示
            if (_dualMode && _recordingFront)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text('フロントカメラ撮影中',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

            // 録画中：残り時間バッジ
            if (_isRecording)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 10),
                        const SizedBox(width: 8),
                        Text(
                          '${_remainingSeconds}秒',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 投稿可能数表示
            Positioned(
              bottom: 140,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isPenalized
                      ? Colors.red.withOpacity(0.8)
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isPenalized ? Colors.red : Colors.white30,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'あと $_postLimit 本',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isPenalized)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'ペナルティ中',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 下部コントロール
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // 進捗バー（録画中のみ）
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              (kMaxRecordingSeconds - _remainingSeconds) /
                              kMaxRecordingSeconds,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.red,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 16),

                  // 撮影ボタン（写真/動画）
                  GestureDetector(
                    onTap:
                        _isInitialized
                            ? (_isPhotoMode
                                ? _takePhoto
                                : (_isRecording ? _stopRecording : _startRecording))
                            : null,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 34 : 68,
                          height: _isRecording ? 34 : 68,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape:
                                _isRecording
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                            borderRadius:
                                _isRecording
                                    ? BorderRadius.circular(8)
                                    : null,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    _isRecording ? 'タップで停止' : 'タップで撮影開始（最大1分）',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 撮影後プレビュー＋編集画面
  // ───────────────────────────────────────────────
  Widget _buildPreviewScreen() {
    final filter = kVideoFilters[_filterIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // 上部バー
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _isUploading ? null : _retake,
                    tooltip: '撮り直す',
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isUploading ? '投稿中...' : '投稿する'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _isUploading ? null : _uploadAndPost,
                  ),
                ],
              ),
            ),

            // プレビュー（写真/動画）
            Expanded(
              child: _recordedVideo != null
                  ? Builder(
                      builder: (context) {
                        // 写真ファイルかどうか判定
                        final isPhoto = _recordedVideo!.path.toLowerCase().endsWith('.jpg') ||
                            _recordedVideo!.path.toLowerCase().endsWith('.png');

                        if (isPhoto) {
                          // 写真プレビュー
                          return Center(
                            child: filter.colorFilter != null
                                ? ColorFiltered(
                                    colorFilter: filter.colorFilter!,
                                    child: Image.file(
                                      File(_recordedVideo!.path),
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Image.file(
                                    File(_recordedVideo!.path),
                                    fit: BoxFit.contain,
                                  ),
                          );
                        }

                        // 動画プレビュー
                        return _previewController != null &&
                                _previewController!.value.isInitialized
                            ? Center(
                                child: AspectRatio(
                                  aspectRatio: _previewController!.value.aspectRatio,
                                  child: filter.colorFilter != null
                                      ? ColorFiltered(
                                          colorFilter: filter.colorFilter!,
                                          child: VideoPlayer(_previewController!),
                                        )
                                      : VideoPlayer(_previewController!),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              );
                      },
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),

            // フィルター選択
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: kVideoFilters.length,
                itemBuilder: (context, index) {
                  final selected = _filterIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _filterIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Text(
                        kVideoFilters[index].name,
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // エフェクト選択
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final effects = ['なし', '✨ キラキラ', '💫 光', '🌈 虹色'];
                  final selected = _effectIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _effectIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.purple
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Text(
                        effects[index],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 結合レイアウト選択（デュアル撮影時のみ表示）
            if (_backVideo != null && _frontVideo != null)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    final layouts = ['↕️ 上下', '↔️ 左右', '🎞️ PiP'];
                    final selected = _mergeLayoutIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _mergeLayoutIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.teal
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: selected
                              ? null
                              : Border.all(color: const Color(0xFF333333)),
                        ),
                        child: Text(
                          layouts[index],
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // トランジション選択
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final transitions = ['なし', '🔄 フェード', '→ スライド', '🔍 ズーム'];
                  final selected = _transitionIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _transitionIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.orange
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Text(
                        transitions[index],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 音楽選択
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final musics = ['なし', '🎵 Upbeat', '😌 Chill', '🎬 Dramatic'];
                  final selected = _musicIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _musicIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.pink
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Text(
                        musics[index],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // キャプション入力
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'キャプションを追加...',
                  hintStyle: const TextStyle(color: Color(0xFF555555)),
                  prefixIcon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF555555), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  counterStyle: const TextStyle(color: Color(0xFF555555)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
