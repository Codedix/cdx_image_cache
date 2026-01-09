import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cdx_image_cache/service.dart';

/// A widget that displays an image from memory using a custom cache service.
/// It supports optional builders for loading and error states, as well as
/// image fade-in animation when the image is fetched asynchronously.
class CachedImageMemory extends StatelessWidget {
  /// The image URL to be fetched and cached.
  final String url;

  /// The custom cache service used to manage image fetching and decoding.
  final MemoryImageCacheService cacheService;

  /// Optional height of the image.
  final double? height;

  /// Optional width of the image.
  final double? width;

  /// Optional image fit
  final BoxFit? fit;

  /// Custom builder to render the image bytes manually (not used here directly).
  final Widget Function(BuildContext context, Uint8List data)? builder;

  /// Widget displayed while loading the image.
  final WidgetBuilder? loadingBuilder;

  /// Widget displayed if an error occurs.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Callback fired when the image has been successfully loaded.
  final void Function(Uint8List data)? onReady;

  /// Callback fired when an error occurs.
  final void Function(Object error)? onError;

  /// Duration for the fade-in animation of the image.
  final Duration fadeDuration;

  const CachedImageMemory({
    super.key,
    required this.url,
    required this.cacheService,
    this.height,
    this.width,
    this.fit,
    this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.onReady,
    this.onError,
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    // If the image is already decoded and available in memory, show it immediately.
    final decoded = cacheService.getDecodedIfAvailable(url);
    if (decoded != null) {
      return RepaintBoundary(child: _imageWidget(decoded));
    }

    // Otherwise, fetch and decode the image asynchronously.
    return RepaintBoundary(
      child: FutureBuilder<ui.Image?>(
        future: cacheService.getDecodedImage(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading placeholder if provided.
            return loadingBuilder?.call(context) ?? const SizedBox.shrink();
          }

          if (snapshot.hasError) {
            // Invoke error callback and return error widget if provided.
            onError?.call(snapshot.error!);
            return errorBuilder?.call(context, snapshot.error!) ??
                const Icon(Icons.error);
          }

          if (snapshot.hasData && snapshot.data != null) {
            final image = snapshot.data!;

            // Fade-in animation for the freshly loaded image.
            return TweenAnimationBuilder<double>(
              duration: fadeDuration,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: _imageWidget(image),
            );
          }

          // Fallback error widget if image is unexpectedly null.
          return errorBuilder?.call(context, Exception("No decoded image")) ??
              const Icon(Icons.broken_image);
        },
      ),
    );
  }

  /// Builds the final image widget from the decoded [ui.Image].
  Widget _imageWidget(ui.Image image) {
    return RawImage(
      key: ValueKey(url),
      image: image,
      fit: fit ?? BoxFit.cover,
      filterQuality: FilterQuality.none,
      height: height,
      width: width,
    );
  }
}
