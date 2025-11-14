import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/models/library_navigation.dart';
import '../../core/models/library_item_model.dart';

class LibraryAudioPlayerScreen extends StatefulWidget {
  const LibraryAudioPlayerScreen({super.key, required this.args});

  final LibraryAudioPlayerArgs args;

  @override
  State<LibraryAudioPlayerScreen> createState() =>
      _LibraryAudioPlayerScreenState();
}

class _LibraryAudioPlayerScreenState extends State<LibraryAudioPlayerScreen> {
  late final AudioPlayer _audioPlayer;
  late int _currentIndex;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  List<LibraryItemModel> get tracks => widget.args.tracks;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _currentIndex =
        widget.args.initialIndex.clamp(0, tracks.length - 1).toInt();
    _initializePlayer();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });
    _completeSub = _audioPlayer.onPlayerComplete.listen((event) {
      _playNext();
    });

    await _playTrack(_currentIndex);
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= tracks.length) return;
    final track = tracks[index];
    final url = track.streamUrl ?? track.fileUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Track "${track.displayTitle}" has no URL.')),
        );
      }
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    setState(() {
      _currentIndex = index;
      _isPlaying = true;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.resume();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _playPrevious() async {
    final previousIndex = _currentIndex - 1;
    if (previousIndex >= 0) {
      await _playTrack(previousIndex);
    }
  }

  Future<void> _playNext() async {
    final nextIndex = _currentIndex + 1;
    if (nextIndex < tracks.length) {
      await _playTrack(nextIndex);
    } else {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _seek(double value) async {
    final position = Duration(
      seconds: (value * _duration.inSeconds).round(),
    );
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = tracks[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.folderTitle ?? 'Audio Player'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.audiotrack,
            size: 96,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Text(
                  currentTrack.displayTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Slider(
                  min: 0,
                  max: _duration.inSeconds > 0 ? 1 : 0,
                  value: _duration.inSeconds > 0
                      ? _position.inSeconds / _duration.inSeconds
                      : 0,
                  onChanged: _duration.inSeconds > 0
                      ? (value) => _seek(value)
                      : null,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position)),
                    Text(_formatDuration(_duration)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _currentIndex > 0 ? _playPrevious : null,
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: _togglePlayPause,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed:
                          _currentIndex < tracks.length - 1 ? _playNext : null,
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                final isActive = index == _currentIndex;
                return ListTile(
                  leading: Icon(
                    isActive ? Icons.equalizer : Icons.music_note,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: track.mimeType != null
                      ? Text(track.mimeType!)
                      : null,
                  trailing: isActive && _isPlaying
                      ? const Icon(Icons.play_arrow)
                      : null,
                  onTap: () => _playTrack(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

