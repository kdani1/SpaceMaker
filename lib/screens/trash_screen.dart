import 'package:flutter/material.dart';
import 'package:spacemaker/gallery.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool busy = false;

  Future<void> _empty() async {
    final g = GalleryStore.instance;
    if (busy || g.trash.isEmpty) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete selected items?'),
      content: const Text('Delete these items from your photo library? Recovery depends on your device. Swiping alone never deletes files.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final count = await g.emptyTrash();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count == 0 ? 'Nothing was deleted. Check Photos permission.' : '$count items deleted by your photo library.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = GalleryStore.instance;
    return Scaffold(
      appBar: AppBar(title: const BrandMark(size: 28, showWordmark: true, compact: true)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(g.trashBytes.asBytes, style: SM.display)),
                const SizedBox(height: 6),
                const Text('Review before deleting. Recovery depends on your device and photo provider.', style: SM.body),
              ],
            ),
          ),
          Expanded(
            child: g.trash.isEmpty
                ? const Center(child: Text('Trash is empty', style: TextStyle(color: SM.text)))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: g.trash.length,
                    itemBuilder: (context, i) {
                      final item = g.trash[i];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AssetThumb(asset: item.asset, size: 300),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: () async {
                                await g.restore(item);
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.undo, color: SM.cream, size: 18),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: GoldButton(
              label: busy ? 'Emptying…' : 'Empty ${g.trashBytes.asBytes}',
              onTap: busy || g.trash.isEmpty ? () {} : _empty,
              enabled: !busy && g.trash.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }
}
