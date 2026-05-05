import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import 'playlist_detail/widgets/song_row.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final List<Song> allSongs;
  final PlayerService player;
  final Map<String, double> downloadProgress;
  final void Function(String videoId) onRemoveSong;
  final void Function(String videoId)? onRemoveFromPlaylist;
  final void Function(String videoId) onDownload;
  final VoidCallback onBack;
  final List<Playlist> playlists;
  final void Function(Song, Playlist) onAddToPlaylist;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.allSongs,
    required this.player,
    required this.downloadProgress,
    required this.onRemoveSong,
    this.onRemoveFromPlaylist,
    required this.onDownload,
    required this.onBack,
    required this.playlists,
    required this.onAddToPlaylist,
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
    if (diff.inDays < 7) return 'hace ${diff.inDays} dias';
    if (diff.inDays < 30) return 'hace ${diff.inDays ~/ 7} semanas';
    if (diff.inDays < 365) return 'hace ${diff.inDays ~/ 30} meses';
    return 'hace ${diff.inDays ~/ 365} anos';
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
                                  '${songs.length} ${songs.length == 1 ? "cancion" : "canciones"}',
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

          SliverToBoxAdapter(
            child: Divider(
              height: 1,
              color: dark ? Colors.white12 : Colors.black12,
              indent: 20,
              endIndent: 20,
            ),
          ),

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
                          'Esta playlist esta vacia',
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
                  return SongRow(
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
                    onRemoveFromPlaylist:
                        widget.playlist.isAuto
                            ? null
                            : () =>
                                widget.onRemoveFromPlaylist?.call(song.videoId),
                    onDownload:
                        song.downloaded
                            ? null
                            : () => widget.onDownload(song.videoId),
                    playlists:
                        widget.playlists
                            .where(
                              (p) => !p.isAuto && p.id != widget.playlist.id,
                            )
                            .toList(),
                    onAddToPlaylist: (s, p) => widget.onAddToPlaylist(s, p),
                    onAddToQueue: () => widget.player.addToQueue(song),
                    onPlayAsNext: () => widget.player.playAsNext(song),
                  );
                }, childCount: songs.length),
              ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
