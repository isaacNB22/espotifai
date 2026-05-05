import 'package:flutter/material.dart';

class LyricsPanel extends StatelessWidget {
  const LyricsPanel({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lyrics_rounded, size: 48, color: Colors.white24),
        SizedBox(height: 12),
        Text(
          'Letra no disponible',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    ),
  );
}
