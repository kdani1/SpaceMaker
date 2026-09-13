import 'dart:convert';

import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MediaKind { all, photos, videos }

enum MediaSort { largest, smallest, newest, oldest }

/// Snapshot of an in-flight library scan, used to drive the progress screen.
class ScanProgress {
  const ScanProgress({
    required this.done,
    required this.total,
    required this.bytes,
    required this.label,
  });

  final int done;
  final int total;
  final int bytes;
  final String label;

  double get value => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);
  int get percent => (value * 100).round();

  static String labelFor(double value) {
    if (value < 0.08) return 'Opening your library';
    if (value < 0.28) return 'Looking through your photos';
    if (value < 0.52) return 'Measuring your videos';
    if (value < 0.74) return 'Working out what eats your storage';
    if (value < 0.92) return 'Ranking the biggest files';
    return 'Almost there';
  }
}

typedef ScanListener = void Function(ScanProgress progress);

class MediaItem {
  MediaItem(this.asset, this.bytes);

  final AssetEntity asset;
  final int bytes;

  bool get isVideo => asset.type == AssetType.video;
  DateTime get created => asset.createDateTime;
  String get id => asset.id;
}

class GalleryStore {
  GalleryStore._();
  static final GalleryStore instance = GalleryStore._();

  static const _keptKey = 'kept_ids';
  static const _trashKey = 'trash_ids';
  static const _sizeKey = 'size_cache';

  /// Measuring a file means asking the platform to resolve it, which is slow.
  /// Results are cached across runs so only new media costs anything.
  final Map<String, int> _sizeCache = {};

  final List<MediaItem> items = [];
  final List<MediaItem> trash = [];
  final Set<String> keptIds = {};
  final Set<String> trashIds = {};
  int totalBytes = 0;
  int photoCount = 0;
  int videoCount = 0;
  bool scanned = false;

  MediaKind kind = MediaKind.videos;
  MediaSort sort = MediaSort.largest;

  Future<PermissionState> request() => PhotoManager.requestPermissionExtend();

  Future<void> loadMarks() async {
    final prefs = await SharedPreferences.getInstance();
    keptIds
      ..clear()
      ..addAll(prefs.getStringList(_keptKey) ?? const []);
    trashIds
      ..clear()
      ..addAll(prefs.getStringList(_trashKey) ?? const []);
  }

  Future<void> _persistMarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keptKey, keptIds.toList());
    await prefs.setStringList(_trashKey, trashIds.toList());
  }

  Future<void> scan({ScanListener? onProgress}) async {
    await loadMarks();
    await _loadSizeCache();
    items.clear();
    trash.clear();
    totalBytes = 0;
    photoCount = 0;
    videoCount = 0;

    var done = 0;
    var total = 0;
    final throttle = Stopwatch()..start();
    void emit({bool force = false}) {
      if (onProgress == null) return;
      if (!force && throttle.elapsedMilliseconds < 60) return;
      throttle.reset();
      final value = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
      onProgress(ScanProgress(
        done: done,
        total: total,
        bytes: totalBytes,
        label: ScanProgress.labelFor(value),
      ));
    }

    emit(force: true);

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      scanned = true;
      return;
    }

    final album = paths.first;
    total = await album.assetCountAsync;
    emit(force: true);

    const pageSize = 200;
    var page = 0;
    while (true) {
      final batch = await album.getAssetListPaged(page: page, size: pageSize);
      if (batch.isEmpty) break;

      final sizes = await _measure(batch, onItem: () {
        done += 1;
        emit();
      });

      for (var i = 0; i < batch.length; i++) {
        final asset = batch[i];
        final bytes = sizes[i];
        totalBytes += bytes;
        if (asset.type == AssetType.video) {
          videoCount += 1;
        } else {
          photoCount += 1;
        }
        final item = MediaItem(asset, bytes);
        if (trashIds.contains(asset.id)) {
          trash.add(item);
        } else if (!keptIds.contains(asset.id)) {
          items.add(item);
        }
      }

      if (batch.length < pageSize) break;
      page += 1;
    }

    done = total;
    emit(force: true);
    await _saveSizeCache();
    scanned = true;
    applyFilter();
  }

  /// Resolves sizes for a page of assets over several lanes at once. The work
  /// is I/O bound, so overlapping requests is far faster than one at a time.
  Future<List<int>> _measure(List<AssetEntity> batch, {required void Function() onItem}) async {
    const lanes = 8;
    final sizes = List<int>.filled(batch.length, 0);
    var next = 0;

    Future<void> lane() async {
      while (true) {
        final index = next++;
        if (index >= batch.length) return;
        sizes[index] = await _sizeOf(batch[index]);
        onItem();
      }
    }

    await Future.wait(List.generate(lanes, (_) => lane()));
    return sizes;
  }

  Future<int> _sizeOf(AssetEntity asset) async {
    final cached = _sizeCache[asset.id];
    if (cached != null) return cached;
    try {
      final file = await asset.originFile;
      final bytes = file?.lengthSync() ?? 0;
      _sizeCache[asset.id] = bytes;
      return bytes;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadSizeCache() async {
    if (_sizeCache.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sizeKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((key, value) => _sizeCache[key] = (value as num).toInt());
    } catch (_) {
      _sizeCache.clear();
    }
  }

  Future<void> _saveSizeCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sizeKey, jsonEncode(_sizeCache));
  }

  List<MediaItem> get deck {
    Iterable<MediaItem> list = items;
    list = switch (kind) {
      MediaKind.all => list,
      MediaKind.photos => list.where((e) => !e.isVideo),
      MediaKind.videos => list.where((e) => e.isVideo),
    };
    final copy = list.toList();
    copy.sort((a, b) {
      return switch (sort) {
        MediaSort.largest => b.bytes.compareTo(a.bytes),
        MediaSort.smallest => a.bytes.compareTo(b.bytes),
        MediaSort.newest => b.created.compareTo(a.created),
        MediaSort.oldest => a.created.compareTo(b.created),
      };
    });
    return copy;
  }

  void applyFilter() {}

  int get trashBytes => trash.fold<int>(0, (sum, e) => sum + e.bytes);

  Future<void> keep(MediaItem item) async {
    items.removeWhere((e) => e.id == item.id);
    keptIds.add(item.id);
    await _persistMarks();
  }

  Future<void> bin(MediaItem item) async {
    items.removeWhere((e) => e.id == item.id);
    if (!trash.any((e) => e.id == item.id)) trash.add(item);
    trashIds.add(item.id);
    keptIds.remove(item.id);
    await _persistMarks();
  }

  Future<void> undoKeep(MediaItem item) async {
    keptIds.remove(item.id);
    if (!items.any((e) => e.id == item.id)) items.add(item);
    await _persistMarks();
  }

  Future<void> restore(MediaItem item) async {
    trash.removeWhere((e) => e.id == item.id);
    trashIds.remove(item.id);
    if (!items.any((e) => e.id == item.id)) items.add(item);
    await _persistMarks();
  }

  Future<int> emptyTrash() async {
    if (trash.isEmpty) return 0;
    final assets = trash.map((e) => e.asset).toList();
    final deleted = await PhotoManager.editor.deleteWithIds(
      assets.map((e) => e.id).toList(),
    );
    trash.removeWhere((e) => deleted.contains(e.id));
    trashIds.removeWhere(deleted.contains);
    await _persistMarks();
    return deleted.length;
  }
}

extension BytesX on int {
  String get asBytes {
    if (this >= 1 << 30) return '${(this / (1 << 30)).toStringAsFixed(1)} GB';
    if (this >= 1 << 20) return '${(this / (1 << 20)).toStringAsFixed(1)} MB';
    if (this >= 1 << 10) return '${(this / (1 << 10)).toStringAsFixed(0)} KB';
    return '$this B';
  }
}
