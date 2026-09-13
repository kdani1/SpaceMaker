import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/gallery.dart';
import 'package:spacemaker/screens/paywall_screen.dart';
import 'package:spacemaker/screens/trash_screen.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';
import 'package:video_player/video_player.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> with SingleTickerProviderStateMixin {
  late List<MediaItem> deck;
  Offset drag = Offset.zero;
  MediaItem? last;
  bool lastWasTrash = false;

  @override
  void initState() {
    super.initState();
    deck = GalleryStore.instance.deck;
  }

  MediaItem? get current => deck.isEmpty ? null : deck.first;

  Future<void> _keep() async {
    final item = current;
    if (item == null) return;
    HapticFeedback.mediumImpact();
    last = item;
    lastWasTrash = false;
    await GalleryStore.instance.keep(item);
    setState(() {
      deck.removeAt(0);
      drag = Offset.zero;
    });
  }

  Future<void> _toss() async {
    final item = current;
    if (item == null) return;
    if (!Entitlement.instance.canDelete) {
      final bought = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaywallScreen(
          freedLabel: GalleryStore.instance.trashBytes.asBytes,
          reason: 'Those five free deletes are used. Subscribe to keep swiping left on this phone.',
        ),
      ));
      if (bought != true || !mounted) {
        setState(() => drag = Offset.zero);
        return;
      }
    }
    final allowed = await Entitlement.instance.consumeDelete();
    if (!allowed) return;
    HapticFeedback.heavyImpact();
    last = item;
    lastWasTrash = true;
    await GalleryStore.instance.bin(item);
    setState(() {
      deck.removeAt(0);
      drag = Offset.zero;
    });
  }

  Future<void> _undo() async {
    final item = last;
    if (item == null) return;
    if (lastWasTrash) {
      await Entitlement.instance.refundDelete();
      await GalleryStore.instance.restore(item);
    } else {
      GalleryStore.instance.keptIds.remove(item.id);
      if (!GalleryStore.instance.items.any((e) => e.id == item.id)) {
        GalleryStore.instance.items.add(item);
      }
    }
    setState(() {
      deck.insert(0, item);
      last = null;
    });
  }

  void _onEnd() {
    if (drag.dx > 120) {
      _keep();
    } else if (drag.dx < -120) {
      _toss();
    } else {
      setState(() => drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = current;
    final angle = drag.dx / 800;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 28, showWordmark: true, compact: true),
        actions: [
          TextButton(
            onPressed: last == null ? null : _undo,
            child: const Text('Undo', style: TextStyle(color: SM.muted)),
          ),
        ],
      ),
      body: item == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Deck is clear', style: TextStyle(color: SM.cream, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Try another filter or empty the trash.', style: TextStyle(color: SM.text)),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen())),
                    child: Text('Trash · ${GalleryStore.instance.trashBytes.asBytes}', style: const TextStyle(color: SM.muted)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('${deck.length} left', style: SM.caption),
                          const Spacer(),
                          Text(item.bytes.asBytes, style: const TextStyle(color: SM.cream, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(Entitlement.instance.statusLabel.toUpperCase(), style: SM.eyebrow),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) => setState(() => drag += d.delta),
                      onHorizontalDragEnd: (_) => _onEnd(),
                      child: Transform.translate(
                        offset: drag,
                        child: Transform.rotate(
                          angle: angle,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaCard(item: item),
                              if (drag.dx > 24)
                                _stamp('KEEP', SM.keep, Alignment.centerLeft),
                              if (drag.dx < -24)
                                _stamp('TRASH', SM.toss, Alignment.centerRight),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _round(Icons.close, SM.toss, _toss),
                    _round(Icons.favorite, SM.keep, _keep),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
                    if (mounted) setState(() {});
                  },
                  child: Text('Trash · ${GalleryStore.instance.trashBytes.asBytes}', style: const TextStyle(color: SM.muted)),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _stamp(String text, Color color, Alignment align) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Transform.rotate(
          angle: align == Alignment.centerLeft ? -math.pi / 10 : math.pi / 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: color, width: 3), borderRadius: BorderRadius.circular(8)),
            child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 28)),
          ),
        ),
      ),
    );
  }

  Widget _round(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: SM.panel, border: Border.all(color: color, width: 2)),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}

class MediaCard extends StatefulWidget {
  const MediaCard({super.key, required this.item});
  final MediaItem item;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  VideoPlayerController? video;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      video?.dispose();
      video = null;
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    if (!widget.item.isVideo) return;
    final file = await widget.item.asset.file;
    if (file == null || !mounted) return;
    final controller = VideoPlayerController.file(File(file.path));
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0);
    await controller.play();
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => video = controller);
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ColoredBox(
        color: SM.panel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.item.isVideo && video != null && video!.value.isInitialized)
              FittedBox(fit: BoxFit.cover, child: SizedBox(width: video!.value.size.width, height: video!.value.size.height, child: VideoPlayer(video!)))
            else
              AssetThumb(asset: widget.item.asset),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  widget.item.isVideo
                      ? 'Video · ${widget.item.bytes.asBytes}'
                      : 'Photo · ${widget.item.bytes.asBytes}',
                  style: const TextStyle(color: SM.cream, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
