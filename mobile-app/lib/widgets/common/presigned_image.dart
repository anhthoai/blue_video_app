import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/file_url_service.dart';

/// Widget that displays images from S3 with automatic presigned URL handling
/// Supports both CDN URLs (direct http/https) and object keys (requires presigned URL)
class PresignedImage extends StatefulWidget {
  final String? imageUrl;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PresignedImage({
    Key? key,
    required this.imageUrl,
    this.placeholder,
    this.errorWidget,
    this.fit,
    this.width,
    this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<PresignedImage> createState() => _PresignedImageState();
}

class _PresignedImageState extends State<PresignedImage> {
  String? _accessibleUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(PresignedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final fileUrlService = FileUrlService();
      final url = await fileUrlService.getAccessibleUrl(widget.imageUrl);

      if (mounted) {
        setState(() {
          _accessibleUrl = url;
          _isLoading = false;
          _hasError = url == null;
        });
      }
    } catch (e) {
      print('Error loading presigned URL: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: widget.borderRadius,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (_hasError || _accessibleUrl == null) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: widget.borderRadius,
            ),
            child: const Icon(Icons.error_outline, color: Colors.grey),
          );
    }

    Widget image = CachedNetworkImage(
      imageUrl: _accessibleUrl!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: (context, url) =>
          widget.placeholder ??
          Container(
            color: Colors.grey[300],
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      errorWidget: (context, url, error) =>
          widget.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          ),
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
