import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/player_service.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final List<Song> allSongs;
  final PlayerService player;
  final Map<String, double> downloadProgress;
  final void Function(String videoId) onRemoveSong;
  final void Function(String videoId) onDownload;
  final VoidCallback onBack;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.allSongs,
    required this.player,
    required this.downloadProgress,
    required this.onRemoveSong,
    required this.onDownload,
    required this.onBack,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.player.removeListener(_onChanged);
    super.dispose();
  }

  List<Song> get _songs {
    if (widget.playlist.isAuto) {
      final id = widget.playlist.id;
      if (id == 'auto_downloaded')
        return widget.allSongs.where((s) => s.downloaded).toList();
      if (id == 'auto_pending')
        return widget.allSongs.where((s) => !s.downloaded).toList();
      return widget.allSongs;
    }
    return widget.playlist.videoIds
        .map(
          (id) => widget.allSongs.firstWhere(
            (s) => s.videoId == id,
            orElse:
                () => Song(videoId: id, title: '', artist: '', thumbnail: ''),
          ),
        )
        .where((s) => s.title.isNotEmpty)
        .toList();
  }

  String _fmt(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'hoy';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    if (diff.inDays < 30) return 'hace ${diff.inDays ~/ 7} semanas';
    if (diff.inDays < 365) return 'hace ${diff.inDays ~/ 30} meses';
    return 'hace ${diff.inDays ~/ 365} años';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final songs = _songs;
    final playlist = widget.playlist;
    final currentId = widget.player.currentSong?.videoId;
    final bg = dark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: dark ? const Color(0xFF121212) : Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBack,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [playlist.color, playlist.color.withAlpha(80), bg],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Art
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: playlist.color,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(60),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              playlist.icon,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Playlist',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withAlpha(180),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  playlist.name,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(160),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Controls bar (solo botón play funcional) ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        songs.isEmpty
                            ? null
                            : () => widget.player.play(songs.first),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            songs.isEmpty
                                ? Colors.grey
                                : const Color(0xFF1DB954),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              color: dark ? Colors.white12 : Colors.black12,
              indent: 20,
              endIndent: 20,
            ),
          ),

          // ── Song list ────────────────────────────────────────────────────
          songs.isEmpty
              ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.music_off_rounded,
                          size: 48,
                          color: dark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Esta playlist está vacía',
                          style: TextStyle(
                            color: dark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final song = songs[i];
                  final isPlaying = song.videoId == currentId;
                  final isCurrentlyPlaying =
                      isPlaying && widget.player.isPlaying;
                  return _SongRow(
                    index: i + 1,
                    song: song,
                    isPlaying: isPlaying,
                    isCurrentlyPlaying: isCurrentlyPlaying,
                    dateAdded: _fmtDate(song.addedAt),
                    duration: _fmt(song.duration),
                    dark: dark,
                    downloadProgress: widget.downloadProgress[song.videoId],
                    onPlay: () => widget.player.playQueue(songs, startIndex: i),
                    onRemove: () => widget.onRemoveSong(song.videoId),
                    onDownload:
                        song.downloaded
                            ? null
                            : () => widget.onDownload(song.videoId),
                  );
                }, childCount: songs.length),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final int index;
  final Song song;
  final bool isPlaying;
  final bool isCurrentlyPlaying;
  final String dateAdded;
  final String duration;
  final bool dark;
  final double?
  downloadProgress; // null = no descargando, 0..1 = progreso, 1.0 = done
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final VoidCallback? onDownload;

  const _SongRow({
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
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1DB954);
    final textColor =
        isPlaying ? green : (dark ? Colors.white : Colors.black87);
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
                // Index / equalizer
                SizedBox(
                  width: 24,
                  child:
                      isCurrentlyPlaying
                          ? const Icon(
                            Icons.equalizer_rounded,
                            color: green,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    song.thumbnail,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color:
                              dark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFDDDDDD),
                          child: Icon(
                            Icons.music_note,
                            size: 16,
                            color: subColor,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + artist
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
                // Date added
                Expanded(
                  flex: 2,
                  child: Text(
                    dateAdded,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),
                // Duration
                SizedBox(
                  width: 36,
                  child: Text(
                    duration,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: subColor,
                  ),
                  onSelected: (v) {
                    if (v == 'remove') onRemove();
                    if (v == 'download') onDownload?.call();
                  },
                  itemBuilder:
                      (_) => [
                        if (onDownload != null)
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Descargar'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Eliminar de biblioteca'),
                            ],
                          ),
                        ),
                      ],
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
                            color: Color(0xFF1DB954),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Descargado',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF1DB954),
                            ),
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
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF1DB954),
                          ),
                        ),
                      ),
            ),
        ],
      ),
    );
  }
}
