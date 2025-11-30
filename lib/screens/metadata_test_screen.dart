import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/audio_metadata_service.dart';

/// 元数据测试页面
class MetadataTestScreen extends StatefulWidget {
  const MetadataTestScreen({super.key});

  @override
  State<MetadataTestScreen> createState() => _MetadataTestScreenState();
}

class _MetadataTestScreenState extends State<MetadataTestScreen> {
  AudioMetadata? _metadata;
  bool _loading = false;
  String? _error;

  /// 选择文件并读取元数据
  Future<void> _pickAndReadFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'm4b', 'flac', 'ogg', 'wav', 'aac'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final metadata = await AudioMetadataService().readMetadataFull(file);
        setState(() => _metadata = metadata);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('元数据测试')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickAndReadFile,
              icon: const Icon(Icons.folder_open),
              label: Text(_loading ? '读取中...' : '选择音频文件'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text('错误: $_error', style: const TextStyle(color: Colors.red)),
            if (_metadata != null) _buildMetadataCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    final m = _metadata!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            if (m.hasCover)
              Center(
                child: Image.memory(m.coverImage!, height: 200, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            // 元数据列表
            _buildRow('文件名', m.fileName),
            _buildRow('标题', m.title ?? '无'),
            _buildRow('艺术家', m.artist ?? '无'),
            _buildRow('专辑', m.album ?? '无'),
            _buildRow('流派', m.genre ?? '无'),
            _buildRow('年份', m.year?.year.toString() ?? '无'),
            _buildRow('曲目号', m.trackNumber?.toString() ?? '无'),
            _buildRow('时长', m.formattedDuration),
            _buildRow('文件大小', m.formattedFileSize),
            _buildRow('文件路径', m.filePath),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
