class Song {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final int? duration; // segundos
  final bool downloaded;
  final DateTime? addedAt;

  const Song({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.duration,
    this.downloaded = false,
    this.addedAt,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      videoId: json['videoId'] as String,
      title: json['title'] as String,
      artist: (json['artist'] ?? json['author']) as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      duration: json['duration'] as int?,
      downloaded:
          json['downloaded'] as bool? ??
          ((json['downloadStatus'] as String?) == 'done'),
      addedAt:
          json['addedAt'] != null
              ? DateTime.tryParse(json['addedAt'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'artist': artist,
    'thumbnail': thumbnail,
    if (duration != null) 'duration': duration,
    'downloaded': downloaded,
    if (addedAt != null) 'addedAt': addedAt!.toIso8601String(),
  };

  Song copyWith({
    String? videoId,
    String? title,
    String? artist,
    String? thumbnail,
    int? duration,
    bool? downloaded,
    DateTime? addedAt,
  }) {
    return Song(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      downloaded: downloaded ?? this.downloaded,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  String get durationFormatted {
    if (duration == null) return '--:--';
    final m = duration! ~/ 60;
    final s = duration! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
