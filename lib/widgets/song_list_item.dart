import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:gihosync/controller/audio_controller.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:gihosync/screen/player_screen.dart';
import 'package:gihosync/constants/app_Colors.dart';

class SongListItem extends StatelessWidget {
  final AppSongModel song;
  final int index;
  final VoidCallback? onTap;
  final audioController = AudioController.instance;

  SongListItem({super.key, required this.song, required this.index, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: _buildArtwork(),
        ),
      ),
      title: Text(
        song.title.split('/').last,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        song.artist,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Appcolors.primary.withValues(alpha: 0.2),
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF8B5CF6), size: 18),
      ),
      onTap: onTap ?? () async {
        await audioController.playPlaylist(startIndex: index);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PlayerScreen()),
          );
        }
      },
    );
  }

  Widget _buildArtwork() {
    if (song.source == SongSource.local) {
      return QueryArtworkWidget(
        id: int.tryParse(song.id) ?? 0,
        type: ArtworkType.AUDIO,
        nullArtworkWidget: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note, color: Colors.white, size: 24),
        ),
      );
    } else {
      if (song.albumArtUrl != null) {
        return Image.network(
          song.albumArtUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 24),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note, color: Colors.white, size: 24),
        );
      }
    }
  }
}
