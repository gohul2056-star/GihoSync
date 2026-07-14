import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gihosync/constants/app_Colors.dart';
import 'package:gihosync/controller/audio_controller.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin {
  final audioController = AudioController.instance;
  late AnimationController _pulseController;
  late AnimationController _bgController;
  late Animation<double> _pulseAnim;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    final bool isLandscape = screenWidth > screenHeight;
    final double artworkSize = isLandscape ? screenHeight * 0.5 : screenWidth * 0.72;

    return Scaffold(
      backgroundColor: Appcolors.bgDark,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFF0A0015), const Color(0xFF1A0533), _bgAnim.value)!,
                      Color.lerp(const Color(0xFF1A0533), const Color(0xFF0D0D2B), _bgAnim.value)!,
                      Color.lerp(const Color(0xFF0D0D2B), const Color(0xFF0A0015), _bgAnim.value)!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
          // Orb — top left
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Orb — bottom right
          Positioned(
            bottom: 80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFEC4899).withValues(alpha: 0.2),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Status banner
                ValueListenableBuilder<String>(
                  valueListenable: audioController.statusMessage,
                  builder: (context, msg, _) {
                    if (msg.isEmpty) return const SizedBox.shrink();
                    final isError = msg.contains('limiting') || msg.contains('error') || msg.contains('Could not');
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isError
                            ? Colors.red.withValues(alpha: 0.8)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isError ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // App bar row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIconBtn(Icons.keyboard_arrow_down_rounded, () => Navigator.pop(context)),
                      const Text(
                        "Now Playing",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      _buildIconBtn(Icons.more_vert_rounded, () => _showPlaylistOptions(context)),
                    ],
                  ),
                ),
                // Main player area
                Expanded(
                  child: StreamBuilder<int?>(
                    stream: audioController.audioPlayer.currentIndexStream,
                    builder: (context, snapshot) {
                      final currentIndex = snapshot.data;
                      final currentSong = (currentIndex != null &&
                              currentIndex >= 0 &&
                              currentIndex < audioController.songs.value.length)
                          ? audioController.songs.value[currentIndex]
                          : null;

                      if (currentSong == null) {
                        return const Center(
                          child: Text("No song playing", style: TextStyle(color: Colors.white60)),
                        );
                      }

                      if (isLandscape) {
                        return _buildLandscapeLayout(currentSong, artworkSize, screenWidth);
                      } else {
                        return _buildPortraitLayout(currentSong, artworkSize, screenWidth, screenHeight);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(AppSongModel currentSong, double artworkSize, double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.02),
          _buildArtworkWithGlow(currentSong, artworkSize),
          SizedBox(height: screenHeight * 0.035),
          _buildSongInfoCard(currentSong),
          SizedBox(height: screenHeight * 0.025),
          _buildProgressBar(context),
          SizedBox(height: screenHeight * 0.02),
          _buildMainControls(screenWidth, false),
          SizedBox(height: screenHeight * 0.02),
          _buildBottomActions(),
          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(AppSongModel currentSong, double artworkSize, double screenWidth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildArtworkWithGlow(currentSong, artworkSize),
          SizedBox(width: screenWidth * 0.05),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSongInfoCard(currentSong),
                const SizedBox(height: 16),
                _buildProgressBar(context),
                const SizedBox(height: 16),
                _buildMainControls(screenWidth, true),
                const SizedBox(height: 16),
                _buildBottomActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkWithGlow(AppSongModel song, double size) {
    final hasImage = song.source == SongSource.youtube && song.albumArtUrl != null;
    return ValueListenableBuilder<bool>(
      valueListenable: audioController.isPlaying,
      builder: (context, playing, child) {
        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, innerChild) {
            return Transform.scale(
              scale: playing ? _pulseAnim.value : 0.95,
              child: innerChild,
            );
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: hasImage
                  ? Image.network(
                      song.albumArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildDefaultArtwork(),
                    )
                  : _buildDefaultArtwork(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF1A0533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Lottie.asset("lib/assets/animation/Untitled file.json", fit: BoxFit.contain),
    );
  }

  Widget _buildSongInfoCard(AppSongModel currentSong) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 28,
                child: Marquee(
                  blankSpace: 30,
                  startPadding: 10,
                  velocity: 40,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  text: currentSong.title.split('/').last,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currentSong.artist,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioController.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = audioController.audioPlayer.duration ?? Duration.zero;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: const Color(0xFF8B5CF6),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFEC4899),
                overlayColor: const Color(0x30EC4899),
              ),
              child: Slider(
                min: 0.0,
                max: duration.inMilliseconds.toDouble() > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                onChanged: (value) {
                  audioController.audioPlayer.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainControls(double screenWidth, bool isLandscape) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous
        GestureDetector(
          onTap: audioController.seekToPrevious,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.all(isLandscape ? 14 : screenWidth * 0.04),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        // Play/Pause — gradient glow button
        StreamBuilder<bool>(
          stream: audioController.audioPlayer.playingStream,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return GestureDetector(
              onTap: audioController.togglePlayPause,
              child: Container(
                padding: EdgeInsets.all(isLandscape ? 18 : screenWidth * 0.055),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            );
          },
        ),
        // Next
        GestureDetector(
          onTap: audioController.seekToNext,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.all(isLandscape ? 14 : screenWidth * 0.04),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        StreamBuilder<bool>(
          stream: audioController.audioPlayer.shuffleModeEnabledStream,
          builder: (context, snapshot) {
            final shuffleEnabled = snapshot.data ?? false;
            return GestureDetector(
              onTap: audioController.toggleShuffle,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: shuffleEnabled
                          ? const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: shuffleEnabled ? null : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: shuffleEnabled
                          ? [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.shuffle_rounded,
                      size: 20,
                      color: shuffleEnabled ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Repeat
        StreamBuilder<LoopMode>(
          stream: audioController.audioPlayer.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            final isActive = loopMode != LoopMode.off;
            final icon = loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded;

            return GestureDetector(
              onTap: audioController.toggleLoop,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isActive ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Playlist options dialogs ────────────────────────────────────────────────

  void _showPlaylistOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xCC1A0533), Color(0xCC0D0D2B)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Color(0x308B5CF6), width: 1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    "Playlist Options",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.add_box_rounded, color: Color(0xFF8B5CF6)),
                    title: const Text("Create New Playlist", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreatePlaylistDialog(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFF8B5CF6)),
                    title: const Text("Add to Playlist", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddToPlaylistDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0533),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("New Playlist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter playlist name",
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await _createNewPlaylist(nameController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Playlist '${nameController.text}' created")),
                  );
                }
              },
              child: const Text("Create", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewPlaylist(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final playlists = prefs.getStringList('playlists') ?? [];
    if (!playlists.contains(name)) {
      playlists.add(name);
      await prefs.setStringList('playlists', playlists);
    }
  }

  void _showAddToPlaylistDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final playlists = prefs.getStringList('playlists') ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0533),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add to Playlist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: playlists.isEmpty
                ? const Text("No playlists found. Create one first.", style: TextStyle(color: Colors.white60))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlistName = playlists[index];
                      return ListTile(
                        leading: const Icon(Icons.queue_music_rounded, color: Color(0xFF8B5CF6)),
                        title: Text(playlistName, style: const TextStyle(color: Colors.white)),
                        onTap: () async {
                          await _addCurrentSongToPlaylist(playlistName);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Added to $playlistName")),
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCurrentSongToPlaylist(String playlistName) async {
    final currentSong = audioController.currentSong;
    if (currentSong == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'playlist_songs_$playlistName';
    final List<String> songList = prefs.getStringList(key) ?? [];

    final songJson = jsonEncode({
      'id': currentSong.id,
      'title': currentSong.title,
      'artist': currentSong.artist,
      'uri': currentSong.uri,
      'albumArtUrl': currentSong.albumArtUrl,
      'source': currentSong.source.toString(),
    });

    if (!songList.contains(songJson)) {
      songList.add(songJson);
      await prefs.setStringList(key, songList);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
