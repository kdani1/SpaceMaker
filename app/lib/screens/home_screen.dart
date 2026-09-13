import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:spacemaker/api.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/gallery.dart';
import 'package:spacemaker/screens/login_screen.dart';
import 'package:spacemaker/screens/paywall_screen.dart';
import 'package:spacemaker/screens/settings_screen.dart';
import 'package:spacemaker/screens/swipe_screen.dart';
import 'package:spacemaker/screens/trash_screen.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool scanning = false;
  bool asking = false;
  String? error;
  PermissionState? permission;
  ScanProgress? progress;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => asking = true);
    final state = await GalleryStore.instance.request();
    setState(() {
      permission = state;
      asking = false;
    });
    if (state.isAuth) await _scan();
  }

  Future<void> _scan() async {
    setState(() {
      scanning = true;
      error = null;
      progress = null;
    });
    try {
      await GalleryStore.instance.scan(onProgress: (p) {
        if (mounted) setState(() => progress = p);
      });
    } catch (e) {
      error = 'Could not read your library. Check photo permission.';
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _openSwipe() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SwipeScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaywallScreen(freedLabel: GalleryStore.instance.trashBytes.asBytes),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final g = GalleryStore.instance;
    final bill = Entitlement.instance;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 30, showWordmark: true, compact: true),
        actions: [
          IconButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await nav.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              if (!mounted) return;
              if (Api.instance.user == null) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              } else {
                setState(() {});
              }
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: asking || scanning
          ? ScanProgressView(
              progress: scanning ? progress : null,
              title: asking ? 'Waiting for photo access' : 'Reading your library',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
              children: [
                Text(bill.statusLabel.toUpperCase(), style: SM.eyebrow),
                const SizedBox(height: 8),
                const Text('Swipe left for storage', style: TextStyle(color: SM.muted, fontSize: 15)),
                const SizedBox(height: 22),
                if (permission?.isAuth != true) ...[
                  Text('SpaceMaker needs full photo access to sort by size and date.', style: SM.body.copyWith(color: SM.cream)),
                  const SizedBox(height: 16),
                  GoldButton(label: 'Allow photo access', onTap: _boot),
                ] else ...[
                  StatNumber(value: g.totalBytes.asBytes, label: 'in photos and videos'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _mini('${g.photoCount}', 'Photos')),
                      const SizedBox(width: 10),
                      Expanded(child: _mini('${g.videoCount}', 'Videos')),
                      const SizedBox(width: 10),
                      Expanded(child: _mini(g.trashBytes.asBytes, 'In trash')),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(error!, style: const TextStyle(color: SM.toss, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  const Text('Start with', style: SM.title),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Largest videos', MediaKind.videos, MediaSort.largest),
                      _chip('Oldest', MediaKind.all, MediaSort.oldest),
                      _chip('Newest photos', MediaKind.photos, MediaSort.newest),
                      _chip('Smallest first', MediaKind.all, MediaSort.smallest),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 22),
                  GoldButton(label: 'Start swiping', onTap: _openSwipe),
                  const SizedBox(height: 10),
                  if (!bill.isPlus)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: _openPaywall,
                        style: _outlineStyle(),
                        child: Text(bill.trialExhausted ? 'Unlock Plus to keep cleaning' : 'See Plus plans'),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
                      if (mounted) setState(() {});
                    },
                    style: _outlineStyle(),
                    child: Text('Review trash · ${g.trashBytes.asBytes}'),
                  ),
                ],
              ],
            ),
    );
  }

  ButtonStyle _outlineStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: SM.cream,
      side: const BorderSide(color: SM.line),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _mini(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: SM.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: SM.line)),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: SM.cream, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(height: 4),
          Text(label, style: SM.caption, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _chip(String label, MediaKind kind, MediaSort sort) {
    final selected = GalleryStore.instance.kind == kind && GalleryStore.instance.sort == sort;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        GalleryStore.instance.kind = kind;
        GalleryStore.instance.sort = sort;
      }),
      selectedColor: SM.muted,
      labelStyle: TextStyle(color: selected ? SM.ink : SM.cream, fontSize: 13),
      backgroundColor: SM.panel,
      side: const BorderSide(color: SM.line),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _filters() {
    final g = GalleryStore.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SM.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: SM.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TYPE', style: SM.eyebrow),
          const SizedBox(height: 10),
          _pills<MediaKind>(
            values: MediaKind.values,
            selected: g.kind,
            label: (k) => switch (k) {
              MediaKind.all => 'All',
              MediaKind.photos => 'Photos',
              MediaKind.videos => 'Videos',
            },
            onPick: (k) => setState(() => g.kind = k),
          ),
          const SizedBox(height: 16),
          const Text('SORT', style: SM.eyebrow),
          const SizedBox(height: 10),
          _pills<MediaSort>(
            values: MediaSort.values,
            selected: g.sort,
            label: (s) => switch (s) {
              MediaSort.largest => 'Large',
              MediaSort.smallest => 'Small',
              MediaSort.newest => 'New',
              MediaSort.oldest => 'Old',
            },
            onPick: (s) => setState(() => g.sort = s),
          ),
        ],
      ),
    );
  }

  Widget _pills<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onPick,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (_) => onPick(value),
            selectedColor: SM.muted,
            labelStyle: TextStyle(color: value == selected ? SM.ink : SM.cream, fontSize: 13),
            backgroundColor: SM.ink,
            side: const BorderSide(color: SM.line),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
