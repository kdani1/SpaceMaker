import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:spacemaker/ads.dart';
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
    Entitlement.instance.addListener(_changed);
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    Entitlement.instance.removeListener(_changed);
    super.dispose();
  }

  Future<void> _openTrash() async {
    if (busy) return;
    setState(() => busy = true);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
    if (mounted) setState(() { busy = false; last = null; deck = GalleryStore.instance.deck; });
  }

  MediaItem? get current => deck.isEmpty ? null : deck.first;

  bool busy = false;
  Future<void> _keep() => _swipe(false);
  Future<void> _toss() => _swipe(true);

  Future<void> _chooseAccess() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PaywallScreen(reason: 'Your 20 free swipes are used. Choose monthly, ad-free Pro or keep cleaning for free with ads.'),
    ));
  }

  Future<void> _adBreak() async {
    final proceed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Nice progress'),
      content: const Text('Your next batch is ready. Continue with a short ad if one is available.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue with ad')),
      ],
    ));
    if (proceed != true || !mounted) return;
    await Ads.instance.showAtBreak();
    await Entitlement.instance.finishAdBreak();
  }

  Future<void> _swipe(bool toss) async {
    if (busy || current == null) return;
    setState(() { busy = true; drag = Offset.zero; });
    try {
      final bill = Entitlement.instance;
      if (!bill.canSwipe) await _chooseAccess();
      if (!mounted || !bill.canSwipe) return;
      if (bill.adDue) await _adBreak();
      if (!mounted || bill.adDue) return;
      final item = current;
      if (item == null) return;
      if (!await bill.recordSwipe()) return;
      if (toss) {
        await GalleryStore.instance.bin(item);
        HapticFeedback.heavyImpact();
      } else {
        await GalleryStore.instance.keep(item);
        HapticFeedback.mediumImpact();
      }
      if (!mounted) return;
      setState(() {
        last = item;
        lastWasTrash = toss;
        deck.removeWhere((e) => e.id == item.id);
      });
      if (!bill.canSwipe) await _chooseAccess();
      if (bill.adsChosen) unawaited(Ads.instance.start());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not finish this swipe. Please retry.')));
    } finally {
      if (mounted) setState(() { busy = false; drag = Offset.zero; });
    }
  }

  Future<void> _undo() async {
    final item = last;
    if (busy || item == null) return;
    setState(() => busy = true);
    try {
      if (lastWasTrash) {
        await GalleryStore.instance.restore(item);
      } else {
        await GalleryStore.instance.undoKeep(item);
      }
      if (!mounted) return;
      setState(() { deck.insert(0, item); last = null; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not undo. Please retry.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _onEnd() {
    if (busy) return;
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
            onPressed: busy || last == null ? null : _undo,
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
                    onPressed: busy ? null : _openTrash,
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
                      onHorizontalDragUpdate: busy ? null : (d) => setState(() => drag += d.delta),
                      onHorizontalDragEnd: (_) => _onEnd(),
                      child: Transform.translate(
                        offset: drag,
                        child: Transform.rotate(
                          angle: angle,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaCard(item: item, active: !busy),
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
                  onPressed: busy ? null : _openTrash,
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
      onTap: busy ? null : onTap,
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
  const MediaCard({super.key, required this.item, this.active = true});
  final bool active;
  final MediaItem item;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> with WidgetsBindingObserver {
  int generation = 0;
  bool foreground = true;
  VideoPlayerController? video;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      video?.dispose();
      video = null;
      _loadVideo();
    } else {
      _playback();
    }
  }

  void _playback() {
    if (widget.active && foreground) { video?.play(); } else { video?.pause(); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    _playback();
  }

  Future<void> _loadVideo() async {
    final token = ++generation;
    if (!widget.item.isVideo) return;
    VideoPlayerController? controller;
    try {
      final file = await widget.item.asset.file;
      if (file == null || !mounted || token != generation) return;
      controller = VideoPlayerController.file(File(file.path));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || token != generation) { await controller.dispose(); return; }
      setState(() => video = controller);
      _playback();
    } catch (_) {
      await controller?.dispose();
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
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
