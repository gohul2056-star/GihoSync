// lib/model/app_song_model.dart
enum SongSource { local, youtube }

class AppSongModel {
  final String id;
  final String title;
  final String artist;
  final String uri;
  final String? albumArt;
  final int? duration;
  final SongSource source;
  final int? artworkId;
  final String? albumArtUrl;

  AppSongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkId,
    required this.uri,
    this.albumArt,
    this.albumArtUrl,
    this.duration,
    required this.source,
  });
}
