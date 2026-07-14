import 'dart:ui';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:gihosync/controller/audio_controller.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:lottie/lottie.dart';
import 'package:marquee/marquee.dart';
import '../screen/player_screen.dart';

class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioController = AudioController.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return StreamBuilder<int?>(
      stream: audioController.audioPlayer.currentIndexStream,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data ?? -1;
        final currentSong = (currentIndex >= 0 && currentIndex < audioController.songs.value.length)
            ? audioController.songs.value[currentIndex]
            : null;

        if (currentSong == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlayerScreen()),
            );
          },
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xCC1A0533),
                      Color(0xCC0D0D2B),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(color: const Color(0x20FFFFFF), width: 1),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05,
                      vertical: screenHeight * 0.015,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          children: [
                            // Album art with glow
                            Container(
                              width: screenWidth * 0.13,
                              height: screenWidth * 0.13,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildArtworkOrAnimation(currentSong),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            // Title and artist
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 22,
                                    child: Marquee(
                                      text: currentSong.title.toString().split('/').last,
                                      blankSpace: 30,
                                      startPadding: 0,
                                      velocity: 40,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentSong.artist,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.skip_previous_rounded, color: Colors.white.withValues(alpha: 0.8), size: 24),
                                  onPressed: audioController.seekToPrevious,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                StreamBuilder<bool>(
                                  stream: audioController.audioPlayer.playingStream,
                                  builder: (context, snapshot) {
                                    final playing = snapshot.data ?? false;
                                    return Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        onPressed: audioController.togglePlayPause,
                                        padding: EdgeInsets.zero,
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.skip_next_rounded, color: Colors.white.withValues(alpha: 0.8), size: 24),
                                  onPressed: audioController.seekToNext,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        // Progress bar
                        StreamBuilder<Duration>(
                          stream: audioController.audioPlayer.positionStream,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration = audioController.audioPlayer.duration ?? Duration.zero;
                            return ProgressBar(
                              progress: position,
                              total: duration,
                              progressBarColor: const Color(0xFF8B5CF6),
                              baseBarColor: Colors.white12,
                              bufferedBarColor: Colors.white10,
                              thumbColor: const Color(0xFFEC4899),
                              thumbRadius: 5,
                              barHeight: 3,
                              timeLabelLocation: TimeLabelLocation.none,
                              onSeek: (duration) => audioController.audioPlayer.seek(duration),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtworkOrAnimation(AppSongModel song) {
    if (song.source == SongSource.youtube && song.albumArtUrl != null) {
      return Image.network(
        song.albumArtUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Lottie.asset("lib/assets/animation/Untitled file.json", fit: BoxFit.contain);
        },
      );
    }
    return Lottie.asset("lib/assets/animation/Untitled file.json", fit: BoxFit.contain);
  }
}
