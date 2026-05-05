import 'package:flutter/material.dart';
import '../../../services/player_service.dart';

class EqPanel extends StatefulWidget {
  final PlayerService player;
  const EqPanel({super.key, required this.player});

  @override
  State<EqPanel> createState() => _EqPanelState();
}

class _EqPanelState extends State<EqPanel> {
  static const _labels = ['60Hz', '230Hz', '910Hz', '3.6k', '14k'];
  static const _indices = [0, 2, 4, 6, 9];

  static const Map<String, List<double>> presets = {
    'Plano': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Graves': [6, 5, 3, 0, 0, 0, 0, -1, -1, -2],
    'Voz': [-2, -1, 0, 3, 5, 5, 3, 1, 0, -1],
    'Acústico': [4, 3, 2, 1, 0, 0, 1, 2, 2, 1],
    'Electrónica': [5, 3, -1, -3, 0, 1, 2, 4, 5, 4],
  };

  void _applyPreset(List<double> values) {
    final p = widget.player;
    setState(() {
      for (int i = 0; i < 10; i++) p.eqBands[i] = values[i];
    });
    for (int i = 0; i < 10; i++) p.setEqBand(i, values[i]);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ecualizador',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  p.resetEq();
                  setState(() {});
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final bandIdx = _indices[i];
                return _VerticalBand(
                  label: _labels[i],
                  value: p.eqBands[bandIdx],
                  onChanged: (v) {
                    setState(() => p.eqBands[bandIdx] = v);
                    p.setEqBand(bandIdx, v);
                  },
                );
              }),
            ),
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            'PRESETS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                presets.entries
                    .map(
                      (e) => _PresetChip(
                        label: e.key,
                        onTap: () => _applyPreset(e.value),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _VerticalBand extends StatelessWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;

  const _VerticalBand({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static const _green = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    final valStr =
        value == 0
            ? '0'
            : (value > 0
                ? '+${value.toStringAsFixed(0)}'
                : value.toStringAsFixed(0));
    return Column(
      children: [
        Text(
          valStr,
          style: TextStyle(
            fontSize: 11,
            color: value == 0 ? Colors.white38 : _green,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: _green,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: value,
                min: -12,
                max: 12,
                divisions: 24,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
