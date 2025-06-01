import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Represents a cached image entry containing the raw bytes and the decoded image.
class ImageCacheEntry {
  final Uint8List bytes;
  ui.Image? image;

  ImageCacheEntry({required this.bytes, this.image});
}

/// Interface for defining a caching strategy for raw image data.
abstract class ImageCacheStrategy {
  ImageCacheEntry? get(String url);
  void put(String url, ImageCacheEntry data);
  void clear({String? url});
  int get currentSize;

  factory ImageCacheStrategy.simple() => _SimpleMapStrategy();
  factory ImageCacheStrategy.lru({required int maxSizeBytes}) =>
      _LruCacheStrategy(maxSizeBytes: maxSizeBytes);
}

/// A simple in-memory map-based cache strategy.
class _SimpleMapStrategy implements ImageCacheStrategy {
  final Map<String, ImageCacheEntry> _cache = {};

  @override
  ImageCacheEntry? get(String url) => _cache[url];

  @override
  void put(String url, ImageCacheEntry data) => _cache[url] = data;

  @override
  void clear({String? url}) {
    url != null ? _cache.remove(url) : _cache.clear();
  }

  @override
  int get currentSize =>
      _cache.values.fold(0, (sum, e) => sum + e.bytes.length);
}

/// A least-recently-used (LRU) cache strategy with a byte size limit.
class _LruCacheStrategy implements ImageCacheStrategy {
  final int maxSizeBytes;
  final LinkedHashMap<String, ImageCacheEntry> _cache = LinkedHashMap();
  int _currentSize = 0;

  _LruCacheStrategy({required this.maxSizeBytes});

  @override
  ImageCacheEntry? get(String url) {
    final entry = _cache.remove(url);
    if (entry == null) return null;
    _cache[url] = entry; // Move to end (recent use)
    return entry;
  }

  @override
  void put(String url, ImageCacheEntry data) {
    if (_cache.containsKey(url)) {
      _currentSize -= _cache[url]!.bytes.length;
      _cache.remove(url);
    }

    while (_currentSize + data.bytes.length > maxSizeBytes &&
        _cache.isNotEmpty) {
      final removed = _cache.remove(_cache.keys.first);
      if (removed != null) _currentSize -= removed.bytes.length;
    }

    _cache[url] = data;
    _currentSize += data.bytes.length;
  }

  @override
  void clear({String? url}) {
    if (url != null) {
      final removed = _cache.remove(url);
      if (removed != null) _currentSize -= removed.bytes.length;
    } else {
      _cache.clear();
      _currentSize = 0;
    }
  }

  @override
  int get currentSize => _currentSize;
}

typedef FetchImageFunction = Future<Uint8List> Function(String url);
typedef DecodeImageFunction = Future<ui.Image> Function(Uint8List bytes);

/// Singleton service for image fetching, decoding, and in-memory caching.
class MemoryImageCacheService {
  MemoryImageCacheService._();
  static final MemoryImageCacheService _instance = MemoryImageCacheService._();
  factory MemoryImageCacheService() => _instance;

  late final ImageCacheStrategy _strategy;
  late final Duration _timeout;
  late final FetchImageFunction _fetch;
  late final DecodeImageFunction _decode;

  final Map<String, Future<ImageCacheEntry?>> _inFlight = {};

  /// Initialize the service with a caching strategy and fetch/decoder functions.
  void init({
    required ImageCacheStrategy strategy,
    required FetchImageFunction fetchFunction,
    Duration fetchTimeout = const Duration(seconds: 8),
    DecodeImageFunction? decodeFunction,
  }) {
    _strategy = strategy;
    _fetch = fetchFunction;
    _timeout = fetchTimeout;
    _decode = decodeFunction ?? _defaultDecoder;
  }

  /// Returns raw bytes if already cached.
  Uint8List? getIfAvailable(String url) => _strategy.get(url)?.bytes;

  /// Returns decoded ui.Image if available.
  ui.Image? getDecodedIfAvailable(String url) => _strategy.get(url)?.image;

  /// Prefetch images in the background.
  void prefetchImages(Iterable<String> urls) {
    for (final url in urls) {
      _prefetch(url);
    }
  }

  void _prefetch(String url) {
    if (_strategy.get(url) != null) return;
    _fetchAndCache(url);
  }

  /// Returns decoded image, fetching and caching if necessary.
  Future<ui.Image?> getDecodedImage(String url) async {
    final cached = _strategy.get(url);
    if (cached?.image != null) {
      _log('Decoded cache hit: $url');
      return cached!.image;
    }

    if (_inFlight.containsKey(url)) {
      _log('Joining ongoing fetch: $url');
      return (await _inFlight[url])?.image;
    }

    return _fetchAndCache(url)?.then((entry) => entry?.image);
  }

  /// Clears the cache (entirely or for a single URL).
  void clearCache({String? url}) => _strategy.clear(url: url);

  /// Awaits the completion of all ongoing image fetches.
  Future<void> waitForAllFetches() async {
    final tasks = _inFlight.values.toList();
    _log('Waiting for ${tasks.length} fetches');
    await Future.wait(tasks);
    _log('All fetches complete');
  }

  /// Internal fetch logic with caching and deduplication.
  Future<ImageCacheEntry?>? _fetchAndCache(String url) {
    if (_inFlight.containsKey(url)) return _inFlight[url]!;

    final future = _fetch(url).timeout(_timeout).then((bytes) async {
      final decoded = await _decode(bytes);
      final entry = ImageCacheEntry(bytes: bytes, image: decoded);
      _strategy.put(url, entry);
      _log('Fetched and cached: $url (${bytes.length} bytes)');
      _inFlight.remove(url);
      return entry;
    }).catchError((e) {
      _log('Fetch error for $url: $e');
      _inFlight.remove(url);
      throw e;
    });

    _log('Starting fetch: $url');
    _inFlight[url] = future;
    return future;
  }

  /// Default image decoder using Flutter's codec.
  static Future<ui.Image> _defaultDecoder(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _log(String msg) => debugPrint('[MemoryImageCacheService] $msg');
}