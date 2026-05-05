import 'package:flutter/material.dart';

/// Botón de ícono para los controles del reproductor.
/// Muestra el ícono en verde Spotify cuando [active] es true.
class PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool active;

  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 24,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(
      icon,
      size: size,
      color: active ? const Color(0xFF1DB954) : Colors.white70,
    ),
    onPressed: onTap,
    splashRadius: 22,
  );
}
