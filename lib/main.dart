import 'package:flutter/material.dart';

void main() {
  runApp(const VoiceBookApp());
}

class VoiceBookApp extends StatelessWidget {
  const VoiceBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceBook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const _ScaffoldPlaceholder(),
    );
  }
}

class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VoiceBook')),
      body: const Center(
        child: Text(
          '项目已初始化。待实现：书架、播放、设置等功能，详见 design.md',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
