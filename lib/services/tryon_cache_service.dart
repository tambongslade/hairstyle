import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Caches generated try-on images locally so re-selecting the same
/// style + photo + color combo loads instantly from disk.
class TryOnCacheService {
  static final TryOnCacheService _instance = TryOnCacheService._();
  static TryOnCacheService get instance => _instance;

  TryOnCacheService._();

  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/tryon_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// Build a unique cache key from the user photo bytes hash, style ID, and color.
  String _buildKey({
    required Uint8List userPhoto,
    required String styleId,
    required int colorIndex,
  }) {
    // Simple hash: combine photo length + first/last bytes + style + color
    final photoHash = userPhoto.length ^
        (userPhoto.isNotEmpty ? userPhoto.first : 0) ^
        (userPhoto.length > 100 ? userPhoto[100] : 0) ^
        (userPhoto.length > 1000 ? userPhoto[1000] : 0) ^
        (userPhoto.isNotEmpty ? userPhoto.last : 0);
    return '${photoHash}_${styleId}_$colorIndex';
  }

  /// Check if a cached result exists for this combination.
  Future<Uint8List?> getCached({
    required Uint8List userPhoto,
    required String styleId,
    required int colorIndex,
  }) async {
    if (kIsWeb) return null; // No filesystem cache on web
    try {
      final dir = await _getCacheDir();
      final key = _buildKey(userPhoto: userPhoto, styleId: styleId, colorIndex: colorIndex);
      final file = File('${dir.path}/$key.png');
      if (await file.exists()) {
        debugPrint('[TryOnCache] Cache HIT: $key');
        return await file.readAsBytes();
      }
      debugPrint('[TryOnCache] Cache MISS: $key');
    } catch (e) {
      debugPrint('[TryOnCache] Error reading cache: $e');
    }
    return null;
  }

  /// Save a generated image to cache.
  Future<void> saveToCache({
    required Uint8List userPhoto,
    required String styleId,
    required int colorIndex,
    required Uint8List generatedImage,
  }) async {
    if (kIsWeb) return; // No filesystem cache on web
    try {
      final dir = await _getCacheDir();
      final key = _buildKey(userPhoto: userPhoto, styleId: styleId, colorIndex: colorIndex);
      final file = File('${dir.path}/$key.png');
      await file.writeAsBytes(generatedImage);
      debugPrint('[TryOnCache] Saved to cache: $key (${(generatedImage.length / 1024).toStringAsFixed(1)} KB)');
    } catch (e) {
      debugPrint('[TryOnCache] Error saving to cache: $e');
    }
  }

  /// Clear all cached try-on images.
  Future<void> clearCache() async {
    if (kIsWeb) return; // No filesystem cache on web
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
        _cacheDir = dir;
        debugPrint('[TryOnCache] Cache cleared');
      }
    } catch (e) {
      debugPrint('[TryOnCache] Error clearing cache: $e');
    }
  }
}
