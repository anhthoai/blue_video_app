import 'package:flutter/material.dart';

class UploadVideoScreen extends StatelessWidget {
  const UploadVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: const Center(child: Text('Upload Video Screen')),
    );
  }
}
