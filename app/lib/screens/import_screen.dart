import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/api_service.dart';

class ImportScreen extends StatefulWidget {
  final ApiService api;
  final void Function(List<Song> songs) onImported;

  const ImportScreen({super.key, required this.api, required this.onImported});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _isError = false;

  Future<void> _import() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _loading = true; _message = null; });
    try {
      final songs = await widget.api.importUrl(url);
      widget.onImported(songs);
      setState(() {
        _isError = false;
        _message = 'Se importaron ${songs.length} canción${songs.length == 1 ? '' : 'es'}';
        _ctrl.clear();
      });
    } on ApiException catch (e) {
      setState(() { _isError = true; _message = e.message; });
    } catch (_) {
      setState(() { _isError = true; _message = 'Error de conexión'; });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Importar URL', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Pega una URL de YouTube (video o playlist) para agregarla directamente a tu biblioteca.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          // URL field
          Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: Icon(Icons.link_rounded, size: 20),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _import(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _import,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_loading ? 'Importando...' : 'Importar'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isError
                    ? cs.errorContainer
                    : const Color(0xFF1DB954).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isError ? cs.error : const Color(0xFF1DB954),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: _isError ? cs.onErrorContainer : const Color(0xFF1DB954),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError ? cs.onErrorContainer : const Color(0xFF1DB954),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
