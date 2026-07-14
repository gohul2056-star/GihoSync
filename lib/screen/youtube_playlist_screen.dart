import 'package:flutter/material.dart';
import 'package:gihosync/controller/audio_controller.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:gihosync/widgets/song_list_item.dart';
import 'package:gihosync/constants/app_Colors.dart';
import 'package:gihosync/utils/custom_text_style.dart';
import 'package:gihosync/widgets/my_button.dart';
import 'package:gihosync/screen/player_screen.dart';
import 'dart:ui';

class YoutubePlaylistScreen extends StatelessWidget {
  final audioController = AudioController.instance;

  YoutubePlaylistScreen({super.key});

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
            onPress: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          "YouTube Songs",
          style: myTextStyle24(fontWeight: FontWeight.bold, fontColor: Appcolors.primary),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<AppSongModel>>(
        valueListenable: audioController.youtubeHistory,
        builder: (context, history, child) {
          // Filter only YouTube songs just in case, though the history should already be YT
          final ytSongs = history.where((s) => s.source == SongSource.youtube).toList();

          if (ytSongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_rounded, size: 64, color: Appcolors.black.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    "No YouTube songs found",
                    style: myTextStyle18(fontColor: Appcolors.black),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            physics: const BouncingScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              audioController.reorderYoutubeHistory(oldIndex, newIndex);
            },
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
            itemCount: ytSongs.length,
            itemBuilder: (context, index) {
              return Padding(
                key: ObjectKey(ytSongs[index]),
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
                  child: SongListItem(
                    song: ytSongs[index],
                    index: index,
                    onTap: () async {
                      await audioController.playYouTubeAsQueue(ytSongs[index]);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PlayerScreen()),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
