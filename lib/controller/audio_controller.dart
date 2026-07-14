import 'dart:async';
import 'dart:io';

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gihosync/model/app_song_model.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

// ---------------------------------------------------------------------------
// Custom exceptions
// ---------------------------------------------------------------------------
class RateLimitException implements Exception {
  @override
  String toString() =>
      'YouTube is temporarily rate-limiting requests from this IP.';
}

class StreamFetchException implements Exception {
  StreamFetchException(this.message);
  final String message;
  @override
  String toString() => 'StreamFetchException: $message';
}

// ---------------------------------------------------------------------------
// Stream URL cache entry — valid for 4 hours.
// NewPipe extracts direct CDN URLs (googlevideo.com) that typically expire
// after 6 hours; we refresh at 4 h to stay safely ahead of expiry.
// ---------------------------------------------------------------------------
class _CachedStreamUrl {
  _CachedStreamUrl(this.url, this.contentType, this.contentLength)
      : _fetchedAt = DateTime.now();

  final String url;
  final String contentType;
  final int contentLength;
  final DateTime _fetchedAt;

  bool get isExpired =>
      DateTime.now().difference(_fetchedAt).inMinutes >= 240;
}

// ---------------------------------------------------------------------------
// NewPipe-based stream fetcher
//
// Uses newpipeextractor_dart (wraps NewPipe's Java extractor) to resolve
// YouTube audio stream URLs. This completely bypasses the PO Token checks
// that break youtube_explode_dart's HTTP clients.
//
// Responsibilities:
//   • Per-video URL caching with 4-hour TTL
//   • In-flight request deduplication
//   • Exponential backoff retry (3 attempts)
//   • Human-readable status messages via [_statusNotifier]
// ---------------------------------------------------------------------------
class _NewPipeStreamFetcher {
  _NewPipeStreamFetcher(this._statusNotifier);

  final ValueNotifier<String> _statusNotifier;

  // Cache: videoId → resolved audio stream URL + metadata
  final Map<String, _CachedStreamUrl> _cache = {};

  // In-flight deduplication
  final Map<String, Completer<_CachedStreamUrl>> _inFlight = {};

  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  /// Returns a cached or freshly-fetched [_CachedStreamUrl] for [videoId].
  Future<_CachedStreamUrl> getStreamUrl(String videoId) async {
    // Cache hit
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      debugPrint('[NP] Cache hit — videoId=$videoId');
      return cached;
    }

    // Deduplication
    if (_inFlight.containsKey(videoId)) {
      debugPrint('[NP] Waiting for in-flight request — videoId=$videoId');
      return _inFlight[videoId]!.future;
    }

    final completer = Completer<_CachedStreamUrl>();
    // Prevent unhandled exception log if caller cancels before completion
    completer.future.catchError((_) => _CachedStreamUrl('', '', 0));
    _inFlight[videoId] = completer;

    try {
      final result = await _fetchWithRetry(videoId);
      _cache[videoId] = result;
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlight.remove(videoId);
    }
  }

  /// Evicts the cached URL for [videoId] so the next call gets a fresh one.
  void invalidate(String videoId) => _cache.remove(videoId);

  Future<_CachedStreamUrl> _fetchWithRetry(String videoId) async {
    final ytUrl = 'https://www.youtube.com/watch?v=$videoId';

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint(
            '[NP] Fetching stream — videoId=$videoId attempt=$attempt');
        _statusNotifier.value = attempt == 1
            ? 'Preparing audio…'
            : 'Retrying… (attempt $attempt/$_maxRetries)';

        // VideoExtractor.getStream calls into the NewPipe Java extractor.
        // It handles bot-detection, signature decryption, and PO tokens
        // internally via the native Android library.
        final YoutubeVideo video = await VideoExtractor.getStream(ytUrl);

        final AudioOnlyStream? bestAudio = video.audioWithHighestQuality;
        String? targetUrl = bestAudio?.url;
        String? targetMimeType = bestAudio?.formatMimeType;
        String? targetSuffix = bestAudio?.formatSuffix;
        
        if (targetUrl == null) {
          // Fallback to muxed stream (video + audio) if audio-only is missing.
          final VideoStream? bestVideo = video.videoWithHighestQuality;
          targetUrl = bestVideo?.url;
          targetMimeType = bestVideo?.formatMimeType;
          targetSuffix = bestVideo?.formatSuffix;
        }

        if (targetUrl == null) {
          throw StreamFetchException('No audio or muxed stream found for $videoId');
        }

        debugPrint(
            '[NP] Stream resolved — videoId=$videoId '
            'mimeType=$targetMimeType');
        _statusNotifier.value = '';

        // Resolve actual content-length via a HEAD request so that
        // just_audio's proxy can build correct range responses.
        final contentLength = await _resolveContentLength(targetUrl);

        return _CachedStreamUrl(
          targetUrl,
          _mimeForFormat(targetMimeType, targetSuffix),
          contentLength,
        );
      } catch (e) {
        debugPrint(
            '[NP] Fetch error — videoId=$videoId attempt=$attempt error=$e');
        if (attempt == _maxRetries) {
          _statusNotifier.value = 'Could not load audio. Please try again.';
          throw StreamFetchException('Failed after $_maxRetries attempts: $e');
        }
        final delay = _retryDelays[attempt - 1];
        debugPrint('[NP] Retrying in ${delay.inSeconds}s…');
        _statusNotifier.value =
            'Retrying in ${delay.inSeconds}s… (attempt $attempt/$_maxRetries)';
        await Future.delayed(delay);
      }
    }
    throw StreamFetchException('Unreachable');
  }

  /// HEAD request to get Content-Length without downloading the body.
  /// Falls back to 0 (unknown length) on any error.
  Future<int> _resolveContentLength(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final lenStr = response.headers['content-length'];
      return int.tryParse(lenStr ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Maps NewPipe format fields to MIME types understood by just_audio.
  String _mimeForFormat(String? mimeType, String? suffix) {
    if (mimeType != null && mimeType.isNotEmpty) return mimeType;
    if (suffix != null) {
      final s = suffix.toLowerCase();
      if (s == 'webm' || s == 'opus') return 'audio/webm';
      if (s == 'm4a' || s == 'mp4') return 'audio/mp4';
    }
    return 'audio/webm'; // safe default
  }
}

// ---------------------------------------------------------------------------
// AudioController
// ---------------------------------------------------------------------------
class AudioController {
  AudioController._internal() {
    audioPlayer.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        seekToNext();
      }
      if (audioPlayer.currentIndex != null &&
          audioPlayer.currentIndex != currentIndex.value) {
        currentIndex.value = audioPlayer.currentIndex!;
        _saveLastPlayed();
        final current = currentSong;
        if (current != null && current.source == SongSource.youtube) {
          _addToYoutubeHistory(current);
          _cleanupOldTempFiles(current.id);
        }
      }
    });
    _loadLastPlayed();
  }

  Future<void> _cleanupOldTempFiles(String currentVideoId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (var file in files) {
        if (file is File && file.path.endsWith('.tmp') && file.path.contains('_part')) {
          if (!file.path.contains(currentVideoId)) {
            await file.delete();
            debugPrint('[NP] Deleted old temp file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('[NP] Temp cleanup error: $e');
    }
  }

  static final AudioController instance = AudioController._internal();

  final audioPlayer = AudioPlayer();
  ConcatenatingAudioSource? _currentPlaylist;
  final songs = ValueNotifier<List<AppSongModel>>([]);
  final youtubeHistory = ValueNotifier<List<AppSongModel>>([]);
  final currentIndex = ValueNotifier<int>(-1);
  final isPlaying = ValueNotifier<bool>(false);

  /// Human-readable status message shown in the UI during stream operations.
  /// Empty string means no active status.
  final statusMessage = ValueNotifier<String>('');

  final OnAudioQuery audioQuery = OnAudioQuery();
  late final _NewPipeStreamFetcher _fetcher =
      _NewPipeStreamFetcher(statusMessage);

  AppSongModel? get currentSong =>
      (currentIndex.value >= 0 && currentIndex.value < songs.value.length)
          ? songs.value[currentIndex.value]
          : null;

  // --- Persistence ---

  Future<void> _saveLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    if (currentIndex.value >= 0 && songs.value.isNotEmpty) {
      final current = songs.value[currentIndex.value];
      await prefs.setInt('last_index', currentIndex.value);
      await prefs.setString('last_source', current.source.toString());
      if (current.source == SongSource.youtube) {
        await prefs.setString('last_yt_id', current.id);
        await prefs.setString('last_yt_title', current.title);
        await prefs.setString('last_yt_artist', current.artist);
        await prefs.setString('last_yt_art', current.albumArtUrl ?? '');
        await prefs.setString('last_yt_uri', current.uri);
      }
    }
  }

  Future<void> _loadLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('last_index') ?? -1;
    final lastSourceStr = prefs.getString('last_source');

    if (lastIndex != -1 && lastSourceStr == SongSource.local.toString()) {
      await loadLocalSongs();
      if (songs.value.length > lastIndex) {
        currentIndex.value = lastIndex;
      }
    } else if (lastIndex != -1 &&
        lastSourceStr == SongSource.youtube.toString()) {
      final id = prefs.getString('last_yt_id');
      final title = prefs.getString('last_yt_title');
      final artist = prefs.getString('last_yt_artist');
      final art = prefs.getString('last_yt_art');
      final uri = prefs.getString('last_yt_uri');

      if (id != null && title != null && uri != null) {
        songs.value = [
          AppSongModel(
            id: id,
            title: title,
            artist: artist ?? 'Unknown',
            uri: uri,
            albumArtUrl: art,
            source: SongSource.youtube,
            artworkId: null,
          )
        ];
        currentIndex.value = 0;
      }
    }
    
    // Load YouTube History
    final historyJson = prefs.getString('youtube_history_v2');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        youtubeHistory.value = decoded.map((item) {
          return AppSongModel(
            id: item['id'],
            title: item['title'],
            artist: item['artist'],
            uri: item['uri'],
            albumArtUrl: item['albumArtUrl'],
            source: SongSource.youtube,
            artworkId: null,
          );
        }).toList();
      } catch (e) {
        debugPrint('[History] Failed to parse history: $e');
      }
    }
  }

  // --- History ---

  Future<void> _addToYoutubeHistory(AppSongModel song) async {
    final list = List<AppSongModel>.from(youtubeHistory.value);
    
    // Remove if already exists to move it to the top
    list.removeWhere((s) => s.id == song.id);
    
    // Add to top
    list.insert(0, song);
    
    // Cap at 15 items
    if (list.length > 15) {
      list.removeRange(15, list.length);
    }
    
    youtubeHistory.value = list;
    
    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'uri': s.uri,
        'albumArtUrl': s.albumArtUrl,
      }).toList();
      await prefs.setString('youtube_history_v2', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[History] Failed to save history: $e');
    }
  }

  Future<void> reorderYoutubeHistory(int oldIndex, int newIndex) async {
    final list = List<AppSongModel>.from(youtubeHistory.value);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final song = list.removeAt(oldIndex);
    list.insert(newIndex, song);

    youtubeHistory.value = list;

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'uri': s.uri,
        'albumArtUrl': s.albumArtUrl,
      }).toList();
      await prefs.setString('youtube_history_v2', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[History] Failed to save history after reorder: $e');
    }
  }

  // --- Local songs ---

  Future<void> loadLocalSongs() async {
    final status = await Permission.audio.request();
    if (!status.isGranted) return;
    final localResults = await audioQuery.querySongs();
    songs.value = localResults
        .map((s) => AppSongModel(
              id: s.id.toString(),
              title: s.title,
              artist: s.artist ?? 'Unknown Artist',
              uri: s.data,
              artworkId: s.id,
              source: SongSource.local,
            ))
        .where((s) => s.uri.isNotEmpty)
        .toList();
  }

  // --- YouTube search ---

  /// Search YouTube for [query] using NewPipe's search extractor.
  Future<void> searchYouTube(String query) async {
    try {
      debugPrint('[Search] Searching YouTube — query="$query"');

      // SearchFilter.videos filters to videos only (no channels/playlists)
      final page = await SearchExtractor.searchYoutube(
        query,
        [SearchFilter.videos.value],
      );

      songs.value = page.result.videos.map((item) {
        // item is a StreamInfoItem: id, name, uploaderName, thumbnails (List<String>)
        final videoId = item.id ?? _extractVideoId(item.url ?? '');
        final thumb = item.thumbnails.isNotEmpty ? item.thumbnails.last : null;
        return AppSongModel(
          id: videoId,
          title: item.name ?? 'Unknown Title',
          artist: item.uploaderName ?? 'Unknown Artist',
          uri: videoId,
          albumArtUrl: thumb,
          source: SongSource.youtube,
          artworkId: null,
        );
      }).toList();

      debugPrint('[Search] Got ${songs.value.length} results');
    } catch (e) {
      debugPrint('[Search] Error: $e');
      songs.value = [];
    }
  }

  /// Extracts a bare video ID from a full YouTube URL.
  String _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    // youtube.com/watch?v=ID
    final fromQuery = uri.queryParameters['v'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    // youtu.be/ID
    if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return url;
  }

  // --- Playback ---

  Future<void> playFilteredPlaylist(
      List<AppSongModel> filteredSongs, int index) async {
    songs.value = filteredSongs;
    await playPlaylist(startIndex: index);
  }

  /// Plays a single YouTube song and fetches related videos to append to the queue.
  Future<void> playYouTubeAsQueue(AppSongModel initialSong) async {
    // 1. Set the initial song and start playing immediately
    songs.value = [initialSong];
    await playPlaylist(startIndex: 0);

    // 2. Fetch related streams in the background
    try {
      final ytUrl = 'https://www.youtube.com/watch?v=${initialSong.id}';
      final related = await VideoExtractor.getRelatedStreams(ytUrl);
      
      final newSongs = related.videos.map((item) {
        final videoId = item.id ?? _extractVideoId(item.url ?? '');
        final thumb = item.thumbnails.isNotEmpty ? item.thumbnails.last : null;
        return AppSongModel(
          id: videoId,
          title: item.name ?? 'Unknown Title',
          artist: item.uploaderName ?? 'Unknown Artist',
          uri: videoId,
          albumArtUrl: thumb,
          source: SongSource.youtube,
          artworkId: null,
        );
      }).toList();

      if (newSongs.isNotEmpty) {
        // Append to our songs list
        songs.value = [initialSong, ...newSongs];
        // Append to the active playlist
        if (_currentPlaylist != null) {
          final newChildren = newSongs.map((song) => _YouTubeStreamSource(song, _fetcher)).toList();
          await _currentPlaylist!.addAll(newChildren);
        }
      }
    } catch (e) {
      debugPrint('[Playback] Failed to fetch related streams for queue: $e');
    }
  }

  /// Builds and starts a playlist from [songs.value] at [startIndex].
  ///
  /// YouTube songs use [_YouTubeStreamSource] which resolves streams on-demand
  /// via [_NewPipeStreamFetcher] (cached, deduplicated, with retry).
  Future<void> playPlaylist({int startIndex = 0, bool autoPlay = true}) async {
    final currentList = songs.value;
    if (currentList.isEmpty || startIndex >= currentList.length) return;

    // Request notification permission for Android 13+ media notifications
    await Permission.notification.request();

    // Invalidate the cache for the target song so we always get a fresh URL.
    final target = currentList[startIndex];
    if (target.source == SongSource.youtube) {
      _fetcher.invalidate(target.id);
    }

    final children = <AudioSource>[];

    for (final song in currentList) {
      if (song.source == SongSource.youtube) {
        children.add(_YouTubeStreamSource(song, _fetcher));
      } else {
        children.add(AudioSource.uri(
          Uri.file(song.uri),
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
          ),
        ));
      }
    }

    currentIndex.value = startIndex;

    final playlist = ConcatenatingAudioSource(
      children: children,
      useLazyPreparation: true,
    );
    _currentPlaylist = playlist;

    try {
      statusMessage.value = 'Preparing audio…';
      await audioPlayer.setAudioSource(playlist, initialIndex: startIndex);
      if (autoPlay) {
        await audioPlayer.play();
        isPlaying.value = true;
      }
      statusMessage.value = '';
    } on RateLimitException {
      // Status message already set — nothing more to do.
    } catch (e) {
      debugPrint('[Playback] Error loading playlist: $e');
      statusMessage.value = 'Playback error. Please try again.';
    }
  }

  // --- Transport controls ---

  void togglePlayPause() =>
      audioPlayer.playing ? audioPlayer.pause() : audioPlayer.play();

  void seekToNext() =>
      audioPlayer.hasNext ? audioPlayer.seekToNext() : null;

  void seekToPrevious() =>
      audioPlayer.hasPrevious ? audioPlayer.seekToPrevious() : null;

  void toggleShuffle() async {
    final enabled = audioPlayer.shuffleModeEnabled;
    await audioPlayer.setShuffleModeEnabled(!enabled);
  }

  void toggleLoop() {
    final next = {
      LoopMode.off: LoopMode.all,
      LoopMode.all: LoopMode.one,
      LoopMode.one: LoopMode.off,
    }[audioPlayer.loopMode]!;
    audioPlayer.setLoopMode(next);
  }

  void dispose() {
    audioPlayer.dispose();
    statusMessage.dispose();
  }
}

// ---------------------------------------------------------------------------
// _YouTubeStreamSource
//
// A just_audio StreamAudioSource backed by a NewPipe-resolved CDN URL.
// Fetches the resolved URL on first access, then proxies byte-range requests
// directly against Google's CDN (googlevideo.com) with proper Range headers.
// ---------------------------------------------------------------------------
class _YouTubeStreamSource extends StreamAudioSource {
  _YouTubeStreamSource(this._song, this._fetcher)
      : super(
          tag: MediaItem(
            id: _song.id,
            title: _song.title,
            artist: _song.artist,
            artUri: _song.albumArtUrl != null
                ? Uri.parse(_song.albumArtUrl!)
                : null,
          ),
        );

  final AppSongModel _song;
  final _NewPipeStreamFetcher _fetcher;
  
  File? _part1File;
  File? _part2File;
  Future<void>? _part1Download;
  Future<void>? _part2Download;

  Future<void> _startDownloads(String url, int contentLength) async {
    if (_part1Download != null) return; // already started
    
    final tempDir = await getTemporaryDirectory();
    _part1File = File('${tempDir.path}/${_song.id}_part1.tmp');
    _part2File = File('${tempDir.path}/${_song.id}_part2.tmp');
    
    // Clear old files if they exist
    if (await _part1File!.exists()) await _part1File!.delete();
    if (await _part2File!.exists()) await _part2File!.delete();

    int half = contentLength ~/ 2;

    _part1Download = _downloadChunk(url, 0, half - 1, _part1File!);
    _part2Download = _downloadChunk(url, half, contentLength - 1, _part2File!);
  }

  Future<void> _downloadChunk(String url, int start, int end, File file) async {
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['Range'] = 'bytes=$start-$end';
      final res = await req.send();
      
      final sink = file.openWrite();
      await res.stream.pipe(sink);
      debugPrint('[NP] Downloaded chunk $start-$end to ${file.path}');
    } catch (e) {
      debugPrint('[NP] Download chunk error: $e');
    }
  }

  Stream<List<int>> _streamGrowingFile(File file, Future<void> downloadFuture) async* {
    int position = 0;
    bool isDownloadComplete = false;
    
    downloadFuture.then((_) => isDownloadComplete = true).catchError((_) => isDownloadComplete = true);

    // Wait for the file to be created by the download task
    while (!await file.exists() && !isDownloadComplete) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    if (await file.exists()) {
      final raf = await file.open(mode: FileMode.read);
      
      while (!isDownloadComplete) {
        final length = await raf.length();
        if (position < length) {
          final bytes = await raf.read(length - position);
          position += bytes.length;
          yield bytes;
        } else {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      // One final read after completion
      final length = await raf.length();
      if (position < length) {
        final bytes = await raf.read(length - position);
        yield bytes;
      }
      
      await raf.close();
    }
  }

  Stream<List<int>> _asyncExpand(List<Stream<List<int>>> streams) async* {
    for (var stream in streams) {
      yield* stream;
    }
  }

  Future<StreamAudioResponse> _fallbackRequest(_CachedStreamUrl cached, int startByte, int? end) async {
      final request = http.Request('GET', Uri.parse(cached.url));
      if (end != null) {
        request.headers['Range'] = 'bytes=$startByte-${end - 1}';
      } else if (startByte > 0) {
        request.headers['Range'] = 'bytes=$startByte-';
      }
      final response = await request.send();
      final totalBytes = cached.contentLength > 0 ? cached.contentLength : null;
      final rangeLength = end != null
          ? end - startByte
          : (totalBytes != null ? totalBytes - startByte : null);

      return StreamAudioResponse(
        sourceLength: totalBytes,
        contentLength: rangeLength,
        offset: startByte,
        stream: response.stream,
        contentType: cached.contentType,
      );
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final startByte = start ?? 0;
    debugPrint('[NP] Stream request — videoId=${_song.id} start=$startByte end=$end');

    try {
      final cached = await _fetcher.getStreamUrl(_song.id);
      
      // If we don't know the content length, fallback to standard stream
      if (cached.contentLength <= 0) {
        debugPrint('[NP] Unknown content length, falling back to direct stream');
        return _fallbackRequest(cached, startByte, end);
      }
      
      // Start parallel downloads if not already started
      await _startDownloads(cached.url, cached.contentLength);
      
      final totalBytes = cached.contentLength;
      final rangeLength = end != null ? end - startByte : (totalBytes - startByte);

      // If just_audio requests an arbitrary seek offset, handle it via fallback
      // to avoid complex file offset seeking
      if (startByte != 0) {
         debugPrint('[NP] Seek detected, falling back to direct stream');
         return _fallbackRequest(cached, startByte, end);
      }

      // Stream Part 1 then Part 2 seamlessly
      Stream<List<int>> combinedStream = _asyncExpand([
        _streamGrowingFile(_part1File!, _part1Download!),
        _streamGrowingFile(_part2File!, _part2Download!),
      ]);

      return StreamAudioResponse(
        sourceLength: totalBytes,
        contentLength: rangeLength,
        offset: startByte,
        stream: combinedStream,
        contentType: cached.contentType,
      );
    } catch (e) {
      debugPrint('[NP] Stream error — videoId=${_song.id} error=$e');
      throw StreamFetchException('Could not fetch stream for ${_song.id}: $e');
    }
  }
}