import 'package:flutter/material.dart';

class Playlist {
  final String id;
  final String name;
  final List<String> videoIds;
  final Color color;
  final IconData icon;
  final bool isAuto;

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'videoIds': videoIds,
    'color': color.value,
    'icon': icon.codePoint,
    'iconFamily': icon.fontFamily ?? 'MaterialIcons',
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    videoIds: List<String>.from(json['videoIds'] as List),
    color: Color(json['color'] as int),
    icon: IconData(
      json['icon'] as int,
      fontFamily: json['iconFamily'] as String? ?? 'MaterialIcons',
    ),
  );
}
