import 'dart:io';

import 'package:photos/core/cache/lru_map.dart';
import 'package:photos/models/photo.dart';

class ImageLruCache {
  static LRUMap<int, File> _map = LRUMap(500);

  static File get(Photo photo) {
    return _map.get(photo.generatedId);
  }

  static void put(Photo photo, File imageData) {
    _map.put(photo.generatedId, imageData);
  }
}