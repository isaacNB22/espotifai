/// Formatea una [Duration] como `m:ss`. Retorna `-:--` si es null.
String fmtDuration(Duration? d) {
  if (d == null) return '-:--';
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
