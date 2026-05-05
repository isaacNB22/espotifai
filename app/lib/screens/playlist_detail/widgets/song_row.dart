import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/playlist.dart';
import '../../../models/song.dart';

/// Fila de canción en el detalle de playlist. Muestra thumbnail, título,
/// artista, fecha, duración y menú de opciones.
class SongRow extends StatelessWidget {
  final int index;
  final Song song;
  final bool isPlaying;
  final bool isCurrentlyPlaying;
  final String dateAdded;
  final String duration;
  final bool dark;

  /// null = no descargando, 0..1 = progreso, 1.0 = completado
  final double? downloadProgress;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onDownload;
  final List<Playlist> playlists;
  final void Function(Song, Playlist) onAddToPlaylist;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onPlayAsNext;

  const SongRow({
    super.key,
    required this.index,
    required this.song,
    required this.isPlaying,
    required this.isCurrentlyPlaying,
    required this.dateAdded,
    required this.duration,
    required this.dark,
    this.downloadProgress,
    required this.onPlay,
    required this.onRemove,
    this.onRemoveFromPlaylist,
    this.onDownload,
    required this.playlists,
    required this.onAddToPlaylist,
    this.onAddToQueue,
    this.onPlayAsNext,
  });

  static const _green = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    final textColor =
        isPlaying ? _green : (dark ? Colors.white : Colors.black87);
    final subColor = dark ? Colors.white54 : Colors.black45;
    final isDownloading = downloadProgress != null && downloadProgress! < 1.0;
    final isDone = downloadProgress != null && downloadProgress! >= 1.0;

    return InkWell(
      onTap: onPlay,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                // Índice / ecualizador animado
                SizedBox(
                  width: 24,
                  child:
                      isCurrentlyPlaying
                          ? const Icon(
                            Icons.equalizer_rounded,
                            color: _green,
                            size: 16,
                          )
                          : Text(
                            '$index',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 13, color: subColor),
                          ),
                ),
                const SizedBox(width: 12),

                // Thumbnail
                _Thumbnail(
                  thumbnail: song.thumbnail,
                  dark: dark,
                  subColor: subColor,
                ),
                const SizedBox(width: 12),

                // Título + artista
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Row(
                        children: [
                          if (!song.downloaded)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.download_for_offline_outlined,
                                size: 12,
                                color: subColor,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Fecha añadida
                Expanded(
                  flex: 2,
                  child: Text(
                    dateAdded,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),

                // Duración
                SizedBox(
                  width: 36,
                  child: Text(
                    duration,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),

                // Menú principal ⋯
                _SongMenu(
                  song: song,
                  subColor: subColor,
                  playlists: playlists,
                  onRemove: onRemove,
                  onRemoveFromPlaylist: onRemoveFromPlaylist,
                  onDownload: onDownload,
                  onAddToQueue: onAddToQueue,
                  onPlayAsNext: onPlayAsNext,
                  onAddToPlaylist: onAddToPlaylist,
                ),
              ],
            ),
          ),

          // Barra de progreso de descarga
          if (isDownloading || isDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 20, 4),
              child:
                  isDone
                      ? Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _green,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Descargado',
                            style: TextStyle(fontSize: 11, color: _green),
                          ),
                        ],
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: downloadProgress,
                          minHeight: 3,
                          backgroundColor:
                              dark ? Colors.white12 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation(_green),
                        ),
                      ),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String thumbnail;
  final bool dark;
  final Color subColor;
  const _Thumbnail({
    required this.thumbnail,
    required this.dark,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF333333) : const Color(0xFFDDDDDD);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: thumbnail,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 40, height: 40, color: bg),
        errorWidget:
            (_, __, ___) => Container(
              width: 40,
              height: 40,
              color: bg,
              child: Icon(Icons.music_note, size: 16, color: subColor),
            ),
      ),
    );
  }
}

class _SongMenu extends StatelessWidget {
  final Song song;
  final Color subColor;
  final List<Playlist> playlists;
  final VoidCallback onRemove;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onPlayAsNext;
  final void Function(Song, Playlist) onAddToPlaylist;

  const _SongMenu({
    required this.song,
    required this.subColor,
    required this.playlists,
    required this.onRemove,
    this.onRemoveFromPlaylist,
    this.onDownload,
    this.onAddToQueue,
    this.onPlayAsNext,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz_rounded, size: 18, color: subColor),
          onSelected: (v) {
            switch (v) {
              case 'remove':
                onRemove();
                break;
              case 'remove_playlist':
                onRemoveFromPlaylist?.call();
                break;
              case 'download':
                onDownload?.call();
                break;
              case 'next':
                onPlayAsNext?.call();
                break;
              case 'queue':
                onAddToQueue?.call();
                break;
            }
          },
          itemBuilder:
              (_) => [
                const PopupMenuItem(
                  value: 'next',
                  child: _MenuRow(
                    icon: Icons.queue_play_next_rounded,
                    label: 'Reproducir siguiente',
                  ),
                ),
                const PopupMenuItem(
                  value: 'queue',
                  child: _MenuRow(
                    icon: Icons.add_to_queue_rounded,
                    label: 'Agregar a la cola',
                  ),
                ),
                const PopupMenuDivider(),
                if (onDownload != null)
                  const PopupMenuItem(
                    value: 'download',
                    child: _MenuRow(
                      icon: Icons.download_rounded,
                      label: 'Descargar',
                    ),
                  ),
                if (onRemoveFromPlaylist != null)
                  const PopupMenuItem(
                    value: 'remove_playlist',
                    child: _MenuRow(
                      icon: Icons.playlist_remove_rounded,
                      label: 'Quitar de la playlist',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: _MenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Eliminar de biblioteca',
                  ),
                ),
              ],
        ),
        if (playlists.isNotEmpty)
          PopupMenuButton<Playlist>(
            icon: Icon(Icons.playlist_add_rounded, size: 18, color: subColor),
            tooltip: 'Agregar a playlist',
            itemBuilder:
                (_) =>
                    playlists
                        .map(
                          (p) => PopupMenuItem<Playlist>(
                            value: p,
                            child: Row(
                              children: [
                                Icon(p.icon, size: 16, color: p.color),
                                const SizedBox(width: 8),
                                Text(p.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
            onSelected: (p) => onAddToPlaylist(song, p),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
  );
}
