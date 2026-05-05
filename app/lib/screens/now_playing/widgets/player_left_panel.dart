import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/player_service.dart';
import '../../../utils/duration_fmt.dart';
import '../../../widgets/common/art_placeholder.dart';
import '../../../widgets/common/player_icon_button.dart';
import '../../../widgets/common/small_chip.dart';

/// Panel izquierdo del reproductor: portada, título, progress bar, controles y volumen.
class PlayerLeftPanel extends StatelessWidget {
  final PlayerService player;
  final bool showEq;
  final VoidCallback onToggleEq;
  final VoidCallback onCrossfadeTap;
  final void Function() onStateChanged;

  const PlayerLeftPanel({
    super.key,
    required this.player,
    required this.showEq,
    required this.onToggleEq,
    required this.onCrossfadeTap,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    final song = p.currentSong;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      song?.thumbnail.isNotEmpty == true
                          ? CachedNetworkImage(
                            imageUrl: song!.thumbnail,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ArtPlaceholder(),
                            errorWidget: (_, __, ___) => const ArtPlaceholder(),
                          )
                          : const ArtPlaceholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Título y artista
          Text(
            song?.title ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            song?.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          const SizedBox(height: 16),

          // Barra de progreso
          _ProgressBar(player: p),
          const SizedBox(height: 4),

          // Controles
          _PlaybackControls(player: p, onStateChanged: onStateChanged),
          const SizedBox(height: 12),

          // Volumen
          _VolumeSlider(player: p, onStateChanged: onStateChanged),
          const SizedBox(height: 8),

          // Chips EQ y Crossfade
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SmallChip(
                icon: Icons.equalizer_rounded,
                label: 'EQ',
                active: p.eqBands.any((b) => b != 0),
                onTap: onToggleEq,
              ),
              const SizedBox(width: 12),
              SmallChip(
                icon: Icons.swap_horiz_rounded,
                label:
                    p.crossfadeSec > 0
                        ? '${p.crossfadeSec.toStringAsFixed(0)}s'
                        : 'Crossfade',
                active: p.crossfadeSec > 0,
                onTap: onCrossfadeTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PlayerService player;
  const _ProgressBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (ctx, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = player.duration;
        final maxMs = (dur?.inMilliseconds.toDouble() ?? 0).clamp(
          1.0,
          double.infinity,
        );
        final valMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: valMs,
                max: maxMs,
                onChanged:
                    (v) => player.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmtDuration(pos),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  Text(
                    fmtDuration(dur),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final PlayerService player;
  final VoidCallback onStateChanged;
  const _PlaybackControls({required this.player, required this.onStateChanged});

  @override
  Widget build(BuildContext context) {
    final p = player;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        PlayerIconButton(
          icon: Icons.shuffle_rounded,
          active: p.shuffle,
          onTap: () {
            p.shuffle = !p.shuffle;
            onStateChanged();
          },
        ),
        PlayerIconButton(
          icon: Icons.skip_previous_rounded,
          size: 32,
          onTap: p.playPrev,
        ),
        _PlayPauseButton(player: p),
        PlayerIconButton(
          icon: Icons.skip_next_rounded,
          size: 32,
          onTap: p.playNext,
        ),
        PlayerIconButton(
          icon: Icons.repeat_rounded,
          active: p.repeat,
          onTap: () {
            p.repeat = !p.repeat;
            onStateChanged();
          },
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final PlayerService player;
  const _PlayPauseButton({required this.player});

  @override
  Widget build(BuildContext context) {
    final p = player;
    return GestureDetector(
      onTap: p.isPlaying ? p.pause : p.resume,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child:
            p.status == PlayerStatus.loading
                ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1DB954),
                  ),
                )
                : Icon(
                  p.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                  color: Colors.black,
                ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final PlayerService player;
  final VoidCallback onStateChanged;
  const _VolumeSlider({required this.player, required this.onStateChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_down_rounded, size: 16, color: Colors.white54),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: player.volume,
              onChanged: (v) {
                player.setVolume(v);
                onStateChanged();
              },
            ),
          ),
        ),
        const Icon(Icons.volume_up_rounded, size: 16, color: Colors.white54),
      ],
    );
  }
}
