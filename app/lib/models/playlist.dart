import 'package:flutter/material.dart';

class Playlist {
  final String id;
  final String name;
  final List<String> videoIds; // vacío = auto-playlist
  final Color color;
  final IconData icon;
  final bool isAuto; // true = generada automáticamente

  const Playlist({
    required this.id,
    required this.name,
    required this.videoIds,
    required this.color,
    required this.icon,
    this.isAuto = false,
  });

  Playlist copyWith({
    String? name,
    List<String>? videoIds,
    Color? color,
    IconData? icon,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      videoIds: videoIds ?? this.videoIds,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isAuto: isAuto,
    );
  }
}
