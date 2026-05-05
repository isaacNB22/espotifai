import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../screens/now_playing_screen.dart';
import '../services/player_service.dart';

class PlayerBar extends StatefulWidget {
  final PlayerService player;
  const PlayerBar({super.key, required this.player});

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  double _volume = 1.0;

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

  String _fmt(Duration? d) {
    if (d == null) return '-:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final song = p.currentSong;

    if (song == null && p.status == PlayerStatus.idle) {
      return const SizedBox.shrink();
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF181818) : const Color(0xFFF8F8F8);
    final muted = dark ? Colors.white54 : Colors.black45;
    const green = Color(0xFF1DB954);

    final sliderTheme = SliderThemeData(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      activeTrackColor: dark ? Colors.white : Colors.black87,
      inactiveTrackColor: dark ? Colors.white24 : Colors.black12,
      thumbColor: dark ? Colors.white : Colors.black87,
      overlayColor: Colors.white24,
    );

    return Material(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar with timestamps
          StreamBuilder<Duration>(
            stream: p.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = p.duration;
              final maxMs = (dur?.inMilliseconds.toDouble() ?? 0).clamp(
                1.0,
                double.infinity,
              );
              final valMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
              return Row(
                children: [
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _fmt(pos),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: valMs,
                        max: maxMs,
                        onChanged:
                            (v) => p.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _fmt(dur),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),

          // Main controls row
          SizedBox(
            height: 56,
            child: Row(
              children: [
                // Left: art + title + artist (toca para abrir NowPlaying)
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        song == null
                            ? null
                            : () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: false,
                              backgroundColor: Colors.transparent,
                              constraints: const BoxConstraints.expand(),
                              builder:
                                  (_) =>
                                      NowPlayingScreen(player: widget.player),
                            ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        if (song != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: song.thumbnail,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder:
                                  (_, __) => Container(
                                    width: 40,
                                    height: 40,
                                    color:
                                        dark
                                            ? const Color(0xFF333333)
                                            : const Color(0xFFEEEEEE),
                                  ),
                              errorWidget:
                                  (_, __, ___) => Container(
                                    width: 40,
                                    height: 40,
                                    color:
                                        dark
                                            ? const Color(0xFF333333)
                                            : const Color(0xFFEEEEEE),
                                    child: Icon(
                                      Icons.music_note,
                                      size: 18,
                                      color: muted,
                                    ),
                                  ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        if (song != null)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: dark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (song.artist.isNotEmpty)
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (song != null && song.downloaded)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: green,
                            ),
                          ),
                      ],
                    ),
                  ), // GestureDetector
                ),

                // Center: playback controls
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BarBtn(
                        icon: Icons.shuffle_rounded,
                        active: p.shuffle,
                        activeColor: green,
                        muted: muted,
                        onTap: () => setState(() => p.shuffle = !p.shuffle),
                      ),
                      _BarBtn(
                        icon: Icons.skip_previous_rounded,
                        muted: muted,
                        onTap: () => p.playPrev(),
                      ),
                      const SizedBox(width: 4),
                      if (p.status == PlayerStatus.loading)
                        const SizedBox(
                          width: 34,
                          height: 34,
                          child: Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: green,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: p.isPlaying ? p.pause : p.resume,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: dark ? Colors.white : Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              p.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: dark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      _BarBtn(
                        icon: Icons.skip_next_rounded,
                        muted: muted,
                        onTap: () => p.playNext(),
                      ),
                      _BarBtn(
                        icon: Icons.repeat_rounded,
                        active: p.repeat,
                        activeColor: green,
                        muted: muted,
                        onTap: () => setState(() => p.repeat = !p.repeat),
                      ),
                    ],
                  ),
                ),

                // Right: volume
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.volume_up_rounded, size: 16, color: muted),
                      SizedBox(
                        width: 88,
                        child: SliderTheme(
                          data: sliderTheme,
                          child: Slider(
                            value: _volume,
                            onChanged: (v) {
                              setState(() => _volume = v);
                              widget.player.setVolume(v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;
  final Color muted;

  const _BarBtn({
    required this.icon,
    required this.onTap,
    required this.muted,
    this.active = false,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Icon(icon, size: 17, color: active ? activeColor : muted),
      ),
    );
  }
}
