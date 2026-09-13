import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:spacemaker/gallery.dart';
import 'package:spacemaker/theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.showWordmark = false, this.compact = false});

  final double size;
  final bool showWordmark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
    if (!showWordmark) return mark;
    return Row(
      children: [
        mark,
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Text(
            'SpaceMaker',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SM.cream,
              fontSize: compact ? 17 : 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full screen scan feedback: a real percentage, a filling bar and a line of
/// copy that changes as the scan moves through the library.
class ScanProgressView extends StatelessWidget {
  const ScanProgressView({super.key, this.progress, this.title = 'Reading your library'});

  final ScanProgress? progress;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final value = p?.value ?? 0;
    final percent = p?.percent ?? 0;
    final label = p?.label ?? 'Getting ready';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 56),
          const SizedBox(height: 28),
          Text(title.toUpperCase(), style: SM.eyebrow),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent.toDouble()),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, shown, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${shown.round()}%',
                style: const TextStyle(
                  color: SM.cream,
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2.4,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, shown, _) => SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: SM.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: shown.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [SM.muted, SM.keep]),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Text(
              label,
              key: ValueKey(label),
              style: SM.title.copyWith(fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p == null || p.total == 0
                ? 'Nothing leaves your phone'
                : '${p.done} of ${p.total} items · ${p.bytes.asBytes} found',
            style: SM.caption,
          ),
        ],
      ),
    );
  }
}

class AssetThumb extends StatelessWidget {
  const AssetThumb({super.key, required this.asset, this.size = 800});

  final AssetEntity asset;
  final int size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(ThumbnailSize(size, size)),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const Center(child: CircularProgressIndicator(color: SM.muted));
        }
        return Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      },
    );
  }
}

class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onTap, this.enabled = true});

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: SM.muted,
          foregroundColor: SM.ink,
          disabledBackgroundColor: SM.line,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
    );
  }
}

class GhostField extends StatelessWidget {
  const GhostField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: SM.cream),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: SM.text),
        filled: true,
        fillColor: SM.panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SM.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SM.muted),
        ),
      ),
    );
  }
}

class StatNumber extends StatelessWidget {
  const StatNumber({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: SM.display),
        ),
        const SizedBox(height: 6),
        Text(label, style: SM.caption, textAlign: TextAlign.center),
      ],
    );
  }
}
