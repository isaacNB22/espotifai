import 'package:flutter/material.dart';

/// Placeholder cuadrado para portada de álbum cuando no hay imagen disponible.
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white12, Colors.white.withAlpha(5)],
      ),
    ),
    child: const Icon(
      Icons.music_note_rounded,
      size: 80,
      color: Colors.white24,
    ),
  );
}
