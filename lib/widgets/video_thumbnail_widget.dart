import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String? thumbnailUrl;
  final String? videoUrl;
  final BoxFit fit;

  const VideoThumbnailWidget({
    super.key,
    required this.thumbnailUrl,
    required this.videoUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Future<Uint8List?>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    if (widget.thumbnailUrl == null && widget.videoUrl != null) {
      _thumbFuture = _generate(widget.videoUrl!);
    }
  }

  Future<Uint8List?> _generate(String videoUrl) async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
      );
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailUrl != null) {
      return Image.network(
        widget.thumbnailUrl!,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (_thumbFuture == null) return _placeholder();

    return FutureBuilder<Uint8List?>(
      future: _thumbFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFF111111),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) return _placeholder();
        return Image.memory(
          data,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }

  Widget _placeholder() => Container(color: const Color(0xFF111111));
}
