import 'package:cdx_image_cache/service.dart';
import 'package:cdx_image_cache/widget.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Entry point of the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures binding for async in main()

  // Initialize the singleton image cache service
  final cacheService = MemoryImageCacheService();
  cacheService.init(
    strategy: ImageCacheStrategy.lru(
      maxSizeBytes: 200 * 1024 * 1024,
    ), // 200 MB cache size
    fetchTimeout: const Duration(seconds: 10),
    fetchFunction: (url) async {
      // you can use any HTTP client or custom logic here
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('Failed to load image');
      return res.bodyBytes;
    },
  );

  // Prefetch a set of image URLs into cache
  cacheService.prefetchImages(_imageUrls);
  await cacheService.waitForAllFetches(); // Wait for prefetch to complete

  runApp(MyApp(cacheService: cacheService));
}

/// Sample list of image URLs
const List<String> _imageUrls = [
  'https://images.unsplash.com/flagged/1/apple-gear-looking-pretty.jpg',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa',
  // Duplicates for demo repetition
  'https://images.unsplash.com/flagged/1/apple-gear-looking-pretty.jpg',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa',
  'https://images.unsplash.com/flagged/1/apple-gear-looking-pretty.jpg',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa',
  'https://images.unsplash.com/flagged/1/apple-gear-looking-pretty.jpg',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa',
  'https://images.unsplash.com/flagged/1/apple-gear-looking-pretty.jpg',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa',
  'https://images.unsplash.com/flagged/1/apple-gear-looking-pretty.jpg',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
  'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa',
];

/// Root widget of the application
class MyApp extends StatelessWidget {
  final MemoryImageCacheService cacheService;

  const MyApp({super.key, required this.cacheService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Cache Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: ListView.builder(
          itemCount: _imageUrls.length,
          itemBuilder: (context, index) {
            final url = _imageUrls[index];
            return CachedImageMemory(
              key: ValueKey(index),
              url: url,
              cacheService: cacheService,
              height: 200,
            );
          },
        ),
      ),
    );
  }
}
