import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToLibrary;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final bool showAddButton;
  final bool showDownloadButton;
  final bool isPlaying;
  final List<Playlist>? playlists;
  final void Function(Song, Playlist)? onAddToPlaylist;

  const SongCard({
    super.key,
    required this.song,
    this.onPlay,
    this.onAddToLibrary,
    this.onDelete,
    this.onDownload,
    this.showAddButton = false,
    this.showDownloadButton = false,
    this.isPlaying = false,
    this.playlists,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: song.thumbnail,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => Container(
                          width: 52,
                          height: 52,
                          color:
                              dark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFDDDDDD),
                        ),
                    errorWidget:
                        (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color:
                              dark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFDDDDDD),
                          child: Icon(
                            Icons.music_note,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                  ),
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.equalizer_rounded,
                        color: Color(0xFF1DB954),
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isPlaying ? const Color(0xFF1DB954) : cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist.isNotEmpty ? '  ·  ' : song.durationFormatted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (song.downloaded)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.download_done_rounded,
                  size: 16,
                  color: Color(0xFF1DB954),
                ),
              ),
            if (showDownloadButton && onDownload != null)
              _ActionBtn(
                icon: Icons.download_rounded,
                tooltip: 'Descargar MP3',
                onTap: onDownload!,
              ),
            if (showAddButton && onAddToLibrary != null)
              _ActionBtn(
                icon: Icons.add_rounded,
                tooltip: 'Agregar a biblioteca',
                onTap: onAddToLibrary!,
              ),
            if (onDelete != null)
              _ActionBtn(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                onTap: onDelete!,
              ),
            // Menú "Agregar a playlist"
            if (onAddToPlaylist != null)
              PopupMenuButton<Playlist?>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                tooltip: 'Más opciones',
                padding: EdgeInsets.zero,
                itemBuilder: (ctx) {
                  final userPlaylists =
                      playlists?.where((p) => !p.isAuto).toList() ?? [];
                  return [
                    const PopupMenuItem<Playlist?>(
                      enabled: false,
                      height: 32,
                      child: Text(
                        'Agregar a playlist',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (userPlaylists.isEmpty)
                      const PopupMenuItem<Playlist?>(
                        enabled: false,
                        height: 36,
                        child: Text(
                          'No hay playlists creadas',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...userPlaylists.map(
                        (p) => PopupMenuItem<Playlist?>(
                          value: p,
                          child: Row(
                            children: [
                              Icon(p.icon, size: 16, color: p.color),
                              const SizedBox(width: 8),
                              Text(p.name),
                            ],
                          ),
                        ),
                      ),
                  ];
                },
                onSelected: (p) {
                  if (p != null) onAddToPlaylist!(song, p);
                },
              ),
            _ActionBtn(
              icon:
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
              tooltip: 'Reproducir',
              onTap: onPlay ?? () {},
              color: const Color(0xFF1DB954),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: size, color: color ?? cs.onSurfaceVariant),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
