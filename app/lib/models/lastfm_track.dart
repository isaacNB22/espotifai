class LastfmTrack {
  final String title;
  final String artist;
  final String thumbnail;
  final String? videoId;
  final String? listeners;

  const LastfmTrack({
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.videoId,
    this.listeners,
  });

  factory LastfmTrack.fromJson(Map<String, dynamic> json) => LastfmTrack(
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    thumbnail: json['thumbnail'] as String? ?? '',
    videoId: json['videoId'] as String?,
    listeners: json['listeners']?.toString(),
  );
}
