import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  final ApiService api;
  final int libraryCount;

  const StatsScreen({super.key, required this.api, required this.libraryCount});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await widget.api.getStats();
      setState(() => _stats = s);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Error de conexión con el servidor');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: const Color(0xFF1DB954),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Estadísticas', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          // Siempre disponible: conteo local
          _StatTile(
            icon: Icons.library_music_rounded,
            label: 'En tu biblioteca',
            value: '${widget.libraryCount}',
            subtitle: widget.libraryCount == 1 ? 'canción' : 'canciones',
            dark: dark,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_stats != null) ...[
            _StatTile(
              icon: Icons.download_done_rounded,
              label: 'Descargadas',
              value: '${_stats!['downloaded'] ?? 0}',
              subtitle: 'archivos MP3',
              dark: dark,
            ),
            const SizedBox(height: 12),
            _QuotaCard(quota: _stats!['quota'] as Map<String, dynamic>?, dark: dark),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final bool dark;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF282828) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1DB954), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: const Color(0xFF1DB954),
                        height: 1.1,
                      ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  final Map<String, dynamic>? quota;
  final bool dark;
  const _QuotaCard({required this.quota, required this.dark});

  @override
  Widget build(BuildContext context) {
    if (quota == null) return const SizedBox.shrink();
    final used = (quota!['used'] as num? ?? 0).toInt();
    final limit = (quota!['limit'] as num? ?? 10000).toInt();
    final percent = (quota!['percent'] as num? ?? 0).toInt();
    final remaining = (quota!['remaining'] as num? ?? limit).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF282828) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.api_rounded, color: Color(0xFF1DB954), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cuota API YouTube', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '$used / $limit',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text('$remaining restantes hoy', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: dark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 80 ? const Color(0xFFE91429) : const Color(0xFF1DB954),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$percent% usado', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
