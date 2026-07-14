import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gihosync/constants/app_Colors.dart';
import 'package:gihosync/controller/audio_controller.dart';
import 'package:gihosync/screen/player_screen.dart';
import 'package:gihosync/screen/youtube_playlist_screen.dart';
import 'package:gihosync/widgets/bottom_player.dart';
import 'package:gihosync/widgets/song_list_item.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'Local_playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required audioHandler});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final audioController = AudioController.instance;
  final TextEditingController _searchController = TextEditingController();
  bool hasPermission = false;
  String query = "";
  bool isLoading = false;
  late AnimationController _bgController;
  late Animation<double> _bgAnim;

  Future<void> checkPermissionAndRequest() async {
    final permission = await Permission.audio.status;
    if (permission.isGranted) {
      setState(() => hasPermission = true);
    } else {
      final result = await Permission.audio.request();
      setState(() => hasPermission = result.isGranted);
    }
    if (!audioController.audioPlayer.playing && audioController.songs.value.isEmpty) {
      await audioController.loadLocalSongs();
    }
  }

  @override
  void initState() {
    super.initState();
    checkPermissionAndRequest();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Decorative orb — top right
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative orb — bottom left
          Positioned(
            bottom: 200,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  Expanded(child: _buildSongList()),
              ],
            ),
          ),
          // Bottom player overlay
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "Giho",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8B5CF6),
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: "Sync",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Nav buttons
              Row(
                children: [
                  _buildNavButton(Icons.home_rounded, () {
                    _searchController.clear();
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() {
                      query = "";
                      isLoading = false;
                    });
                    audioController.loadLocalSongs();
                  }),
                  const SizedBox(width: 8),
                  _buildNavButton(Icons.library_music, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LocalPlaylistScreen()));
                  }),
                  const SizedBox(width: 8),
                  _buildNavButton(Icons.video_library, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => YoutubePlaylistScreen()));
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Glass search bar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search songs, artists...",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() => query = value);
                    if (value.isEmpty &&
                        audioController.songs.value.isNotEmpty &&
                        audioController.songs.value.first.source != SongSource.youtube) {
                      audioController.loadLocalSongs();
                    }
                  },
                  onSubmitted: (value) async {
                    if (value.trim().isNotEmpty) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => isLoading = true);
                      await audioController.searchYouTube(value);
                      setState(() => isLoading = false);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSongList() {
    return ValueListenableBuilder<List<AppSongModel>>(
      valueListenable: audioController.songs,
      builder: (context, songs, child) {
        final isYoutubeList = songs.isNotEmpty && songs.first.source == SongSource.youtube;
        final filtered = isYoutubeList
            ? songs
            : songs.where((song) {
                final q = query.toLowerCase();
                return song.title.toLowerCase().contains(q) || song.artist.toLowerCase().contains(q);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ).createShader(bounds),
                  child: const Icon(Icons.music_off_rounded, size: 72, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  query.isNotEmpty ? "No results found" : "No songs found",
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final song = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: SongListItem(
                      song: song,
                      index: index,
                      onTap: () async {
                        if (!isYoutubeList && query.isNotEmpty) {
                          await audioController.playFilteredPlaylist(filtered, index);
                        } else if (isYoutubeList && query.isNotEmpty) {
                          // Tapped a YouTube search result: play it and generate a related videos queue
                          await audioController.playYouTubeAsQueue(song);
                        } else {
                          await audioController.playPlaylist(startIndex: index);
                        }
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PlayerScreen()),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
