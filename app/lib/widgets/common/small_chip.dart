import 'package:flutter/material.dart';

/// Chip pequeño con ícono y etiqueta. Borde y texto verdes cuando está activo.
class SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const SmallChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  static const _green = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _green.withAlpha(40) : Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? _green : Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? _green : Colors.white54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? _green : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
