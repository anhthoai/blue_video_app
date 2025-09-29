import 'package:flutter/material.dart';

class VideoPlayerScreen extends StatelessWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Player')),
      body: Center(child: Text('Video Player Screen - ID: $videoId')),
    );
  }
}
