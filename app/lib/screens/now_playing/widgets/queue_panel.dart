import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/player_service.dart';

class QueuePanel extends StatefulWidget {
  final PlayerService player;
  const QueuePanel({super.key, required this.player});

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> {
  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final queue = p.queue;
    final current = p.queueIndex;

    if (queue.isEmpty) {
      return const Center(
        child: Text(
          'Cola vacía.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      proxyDecorator:
          (child, _, __) => Material(color: Colors.transparent, child: child),
      onReorder:
          (oldIdx, newIdx) => setState(() => p.reorderQueue(oldIdx, newIdx)),
      itemBuilder: (ctx, i) {
        final song = queue[i];
        final isCurrent = i == current;
        return ListTile(
          key: ValueKey('${song.videoId}_$i'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          leading: _QueueThumbnail(
            thumbnail: song.thumbnail,
            isCurrent: isCurrent,
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  isCurrent
                      ? const Color(0xFF1DB954).withAlpha(180)
                      : Colors.white54,
              fontSize: 12,
            ),
          ),
          onTap: isCurrent ? null : () => p.jumpToIndex(i),
          trailing: ReorderableDragStartListener(
            index: i,
            child: const Icon(
              Icons.drag_handle_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

class _QueueThumbnail extends StatelessWidget {
  final String thumbnail;
  final bool isCurrent;

  const _QueueThumbnail({required this.thumbnail, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: thumbnail,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorWidget:
                (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  color: Colors.white12,
                  child: const Icon(
                    Icons.music_note,
                    size: 16,
                    color: Colors.white38,
                  ),
                ),
          ),
        ),
        if (isCurrent)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.equalizer_rounded,
                size: 10,
                color: Colors.black,
              ),
            ),
          ),
      ],
    );
  }
}
