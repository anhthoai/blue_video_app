import 'package:flutter/material.dart';

class VideoDetailScreen extends StatelessWidget {
  final String videoId;

  const VideoDetailScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Detail')),
      body: Center(child: Text('Video Detail Screen - ID: $videoId')),
    );
  }
}
