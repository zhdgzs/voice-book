import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/permission_service.dart';
import '../services/file_scanner_service.dart';
import '../providers/book_provider.dart';
import '../models/book.dart';
import '../models/audio_file.dart';

/// 文件导入页面
///
/// 新的导入流程：
/// 1. 用户选择文件夹
/// 2. 扫描该文件夹下的音频文件
/// 3. 将所有音频文件作为一本书籍导入
/// 4. 书籍名称默认为文件夹名，可修改
class FileImportScreen extends StatefulWidget {
  const FileImportScreen({super.key});

  @override
  State<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends State<FileImportScreen> {
  final _permissionService = PermissionService();
  final _scannerService = FileScannerService();
  final _bookNameController = TextEditingController();
  final _authorController = TextEditingController();

  bool _hasPermission = false;
  bool _isScanning = false;
  String? _selectedFolderPath;
  String? _selectedFolderName;
  List<File> _scannedFiles = [];
  String _statusMessage = '准备就绪';

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _bookNameController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  /// 检查权限状态
  Future<void> _checkPermission() async {
    final hasPermission = await _permissionService.checkStoragePermission();
    setState(() {
      _hasPermission = hasPermission;
      _statusMessage = hasPermission ? '已有存储权限，请选择文件夹' : '需要请求存储权限';
    });
  }

  /// 请求权限
  Future<void> _requestPermission() async {
    setState(() {
      _statusMessage = '正在请求权限...';
    });

    final granted = await _permissionService.requestStoragePermission();

    setState(() {
      _hasPermission = granted;
      _statusMessage = granted ? '权限已授予，请选择文件夹' : '权限被拒绝';
    });

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('需要存储权限才能扫描音频文件'),
            action: SnackBarAction(
              label: '打开设置',
              onPressed: PermissionService().openSettings,
            ),
          ),
        );
      }
    }
  }

  /// 选择文件夹
  Future<void> _pickFolder() async {
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    try {
      // 使用文件选择器选择目录
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        final folderName = result.split(Platform.pathSeparator).last;

        setState(() {
          _selectedFolderPath = result;
          _selectedFolderName = folderName;
          _bookNameController.text = folderName;
          _statusMessage = '已选择文件夹: $folderName';
          _scannedFiles.clear();
        });

        // 自动开始扫描
        await _scanFolder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }

  /// 扫描文件夹
  Future<void> _scanFolder() async {
    if (_selectedFolderPath == null) return;

    setState(() {
      _isScanning = true;
      _statusMessage = '正在扫描文件夹...';
      _scannedFiles.clear();
    });

    try {
      // 扫描文件夹（不递归，只扫描当前文件夹）
      final files = await _scannerService.scanDirectory(
        _selectedFolderPath!,
        recursive: false, // 不递归，避免扫描过多文件
        onProgress: (count) {
          setState(() {
            _statusMessage = '已找到 $count 个音频文件...';
          });
        },
      );

      // 按文件名排序
      files.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        _scannedFiles = files;
        _statusMessage = '扫描完成！找到 ${files.length} 个音频文件';
      });

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该文件夹中没有找到音频文件')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = '扫描失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// 导入书籍
  Future<void> _importBook() async {
    if (_scannedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导入的音频文件')),
      );
      return;
    }

    final bookName = _bookNameController.text.trim();
    if (bookName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入书籍名称')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = '正在导入书籍...';
    });

    try {
      final bookProvider = context.read<BookProvider>();

      // 计算总时长（简单估算，不读取元数据以避免卡顿）
      // 实际时长将在后台异步更新
      final totalDuration = 0;

      // 创建书籍
      final book = Book(
        title: bookName,
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        totalDuration: totalDuration,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final createdBook = await bookProvider.createBook(book);
      if (createdBook == null) {
        throw Exception('创建书籍失败');
      }

      // 创建音频文件记录（不读取元数据，快速导入）
      final db = await bookProvider.databaseService.database;
      for (int i = 0; i < _scannedFiles.length; i++) {
        final file = _scannedFiles[i];
        final audioFile = AudioFile(
          bookId: createdBook.id!,
          filePath: file.path,
          fileName: file.path.split(Platform.pathSeparator).last,
          fileSize: await file.length(),
          duration: 0, // 暂时设为0，后续可以异步更新
          sortOrder: i,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );

        await db.insert('audio_files', audioFile.toMap());
      }

      setState(() {
        _statusMessage = '导入完成！';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入《$bookName》，共 ${_scannedFiles.length} 个音频文件'),
          ),
        );

        // 延迟后返回书架
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '导入失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入书籍'),
        actions: [
          if (_scannedFiles.isNotEmpty)
            TextButton.icon(
              onPressed: _isScanning ? null : _importBook,
              icon: const Icon(Icons.check),
              label: const Text('导入'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 状态卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasPermission ? Icons.check_circle : Icons.warning,
                            color: _hasPermission ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (_isScanning) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 选择文件夹按钮
              if (!_hasPermission)
                ElevatedButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('请求权限'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

              // 已选择的文件夹信息
              if (_selectedFolderPath != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '书籍信息',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // 书籍名称
                        TextField(
                          controller: _bookNameController,
                          decoration: const InputDecoration(
                            labelText: '书籍名称 *',
                            hintText: '请输入书籍名称',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.book),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 作者
                        TextField(
                          controller: _authorController,
                          decoration: const InputDecoration(
                            labelText: '作者（可选）',
                            hintText: '请输入作者名称',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 文件夹路径
                        Row(
                          children: [
                            Icon(Icons.folder, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFolderPath!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 文件数量
                        Row(
                          children: [
                            Icon(Icons.audio_file, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              '共 ${_scannedFiles.length} 个音频文件',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 文件列表
              if (_scannedFiles.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '音频文件列表',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _scannedFiles.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = _scannedFiles[index];
                      final fileName =
                          file.path.split(Platform.pathSeparator).last;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: FutureBuilder<int>(
                          future: file.length(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final size = snapshot.data!;
                              final sizeStr = size < 1024 * 1024
                                  ? '${(size / 1024).toStringAsFixed(1)} KB'
                                  : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                              return Text(
                                sizeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],

              // 使用说明
              if (_selectedFolderPath == null && _hasPermission) ...[
                const SizedBox(height: 24),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '使用说明',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. 点击"选择文件夹"按钮\n'
                          '2. 选择包含音频文件的文件夹\n'
                          '3. 系统会自动扫描该文件夹下的音频文件\n'
                          '4. 确认书籍名称和作者信息\n'
                          '5. 点击"导入"按钮完成导入',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '提示：为避免卡顿，系统只扫描选中文件夹，不会递归扫描子文件夹',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
