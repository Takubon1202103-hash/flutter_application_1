import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/post_service.dart';
import '../services/shot_state.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _controller?.dispose();
    _previewController?.dispose();
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

      await PostService.uploadPost(
        File(_recordedVideo!.path),
        isLate: isLate,
        frontVideoFile: _frontVideo != null ? File(_frontVideo!.path) : null,
      );

      if (mounted) {
        shotState.markPosted(DateTime.now());
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('フロントカメラで自撮りを撮影してください'),
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

                  // 録画ボタン
                  GestureDetector(
                    onTap:
                        _isInitialized
                            ? (_isRecording ? _stopRecording : _startRecording)
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
  // 撮影後プレビュー画面
  // ───────────────────────────────────────────────
  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _previewController != null &&
                          _previewController!.value.isInitialized
                      ? Center(
                        child: AspectRatio(
                          aspectRatio: _previewController!.value.aspectRatio,
                          child: VideoPlayer(_previewController!),
                        ),
                      )
                      : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        '撮り直す',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _retake,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isUploading ? 'アップロード中...' : '投稿する'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isUploading ? null : _uploadAndPost,
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
}
