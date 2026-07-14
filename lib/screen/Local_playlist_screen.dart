import 'package:flutter/material.dart';
import 'package:gihosync/controller/audio_controller.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:gihosync/screen/player_screen.dart';
import 'package:gihosync/widgets/song_list_item.dart';
import 'package:gihosync/constants/app_Colors.dart';
import 'package:gihosync/utils/custom_text_style.dart';
import 'package:gihosync/widgets/my_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';

class LocalPlaylistScreen extends StatefulWidget {
  LocalPlaylistScreen({super.key});

  @override
  State<LocalPlaylistScreen> createState() => _LocalPlaylistScreenState();
}

class _LocalPlaylistScreenState extends State<LocalPlaylistScreen> {
  final audioController = AudioController.instance;
  List<String> playlists = [];
  String? selectedPlaylist;
  List<AppSongModel> playlistSongs = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      playlists = prefs.getStringList('playlists') ?? [];
    });
  }

  Future<void> _loadPlaylistSongs(String playlistName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'playlist_songs_$playlistName';
    final List<String> songListJson = prefs.getStringList(key) ?? [];
    
    final List<AppSongModel> loadedSongs = [];
    
    for (String jsonStr in songListJson) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        // Map SongSource enum back
        SongSource source = SongSource.local;
        if (data['source'] == 'SongSource.youtube') {
           source = SongSource.youtube;
        }

        loadedSongs.add(AppSongModel(
          id: data['id'],
          title: data['title'],
          artist: data['artist'],
          uri: data['uri'],
          albumArtUrl: data['albumArtUrl'],
          source: source,
          artworkId: null 
        ));
      } catch (e) {
        debugPrint("Error parsing song from playlist: $e");
      }
    }

    setState(() {
      selectedPlaylist = playlistName;
      playlistSongs = loadedSongs;
    });
  }

  Future<void> _deletePlaylist(String playlistName) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentPlaylists = prefs.getStringList('playlists') ?? [];
    
    if (currentPlaylists.contains(playlistName)) {
      currentPlaylists.remove(playlistName);
      await prefs.setStringList('playlists', currentPlaylists);
      await prefs.remove('playlist_songs_$playlistName');
      
      setState(() {
        playlists = currentPlaylists;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Playlist '$playlistName' deleted")),
      );
    }
  }

  Future<void> _removeSongFromPlaylist(int index) async {
    if (selectedPlaylist == null) return;
    
    final songToRemove = playlistSongs[index];
    setState(() {
      playlistSongs.removeAt(index);
    });

    final prefs = await SharedPreferences.getInstance();
    final key = 'playlist_songs_$selectedPlaylist';
    
    // We need to re-encode the entire list to remove the specific item at that index
    // because multiple songs might be identical, so removing by value is risky if duplicates allowed
    // But persistence stores JSON strings.
    
    // Let's rebuild the stored list from the current 'playlistSongs'
    final List<String> newJsonList = playlistSongs.map((song) {
       return jsonEncode({
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'uri': song.uri,
        'albumArtUrl': song.albumArtUrl,
        'source': song.source.toString(),
      });
    }).toList();

    await prefs.setStringList(key, newJsonList);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Removed '${songToRemove.title}'")),
    );
  }

  Future<void> _reorderSong(int oldIndex, int newIndex) async {
    if (selectedPlaylist == null) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final song = playlistSongs.removeAt(oldIndex);
      playlistSongs.insert(newIndex, song);
    });

    final prefs = await SharedPreferences.getInstance();
    final key = 'playlist_songs_$selectedPlaylist';
    
    final List<String> newJsonList = playlistSongs.map((song) {
       return jsonEncode({
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'uri': song.uri,
        'albumArtUrl': song.albumArtUrl,
        'source': song.source.toString(),
      });
    }).toList();

    await prefs.setStringList(key, newJsonList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Appcolors.secondary,
      appBar: AppBar(
        backgroundColor: Appcolors.secondary,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: MyButton(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPress: () {
              if (selectedPlaylist != null) {
                setState(() {
                  selectedPlaylist = null;
                  playlistSongs = [];
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        title: Text(
          selectedPlaylist ?? "Playlists", 
          style: myTextStyle24(fontWeight: FontWeight.bold, fontColor: Appcolors.primary)
        ),
        centerTitle: true,
      ),
      body: selectedPlaylist == null 
        ? _buildPlaylistList() 
        : _buildSongList(),
    );
  }

  Widget _buildPlaylistList() {
    if (playlists.isEmpty) {
       return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.queue_music_rounded, size: 64, color: Appcolors.black.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text("No playlists yet", style: myTextStyle18(fontColor: Appcolors.black)),
            ],
          ),
        );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final name = playlists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Appcolors.secondary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                 BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 10,
                ),
                 BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: const Icon(Icons.folder_special_rounded, color: Appcolors.primary, size: 32),
              title: Text(name, style: myTextStyle18(fontWeight: FontWeight.bold, fontColor: Appcolors.black)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _confirmDeletePlaylist(name),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                ],
              ),
              onTap: () => _loadPlaylistSongs(name),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeletePlaylist(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Playlist"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePlaylist(name);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    if (playlistSongs.isEmpty) {
       return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off_rounded, size: 64, color: Appcolors.black.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text("Empty playlist", style: myTextStyle18(fontColor: Appcolors.black)),
            ],
          ),
        );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      physics: const BouncingScrollPhysics(),
      onReorder: _reorderSong,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            final double animValue = Curves.easeInOut.transform(animation.value);
            final double elevation = lerpDouble(0, 6, animValue)!;
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor: Colors.black.withOpacity(0.5),
              child: child,
            );
          },
          child: child,
        );
      },
      itemCount: playlistSongs.length,
      itemBuilder: (context, index) {
        return Padding(
          key: ObjectKey(playlistSongs[index]),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Appcolors.secondary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                 BoxShadow(
                  color: Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 10,
                ),
                 BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: SongListItem(
                song: playlistSongs[index], 
                index: index,
                onTap: () async {
                   await audioController.playFilteredPlaylist(playlistSongs, index);
                   if (mounted) {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const PlayerScreen())
                      );
                   }
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                onPressed: () => _removeSongFromPlaylist(index),
              ),
            ),
          ),
        );
      },
    );
  }
}
