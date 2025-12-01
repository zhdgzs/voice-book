import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/database_service.dart';
import '../utils/helpers.dart';

/// 书签列表对话框
class BookmarkListDialog extends StatefulWidget {
  final int audioFileId;
  final Function(int position) onBookmarkTap;

  const BookmarkListDialog({
    super.key,
    required this.audioFileId,
    required this.onBookmarkTap,
  });

  @override
  State<BookmarkListDialog> createState() => _BookmarkListDialogState();
}

class _BookmarkListDialogState extends State<BookmarkListDialog> {
  final _dbService = DatabaseService();
  List<Bookmark> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final db = await _dbService.database;
    final maps = await db.query(
      'bookmarks',
      where: 'audio_file_id = ?',
      whereArgs: [widget.audioFileId],
      orderBy: 'position ASC',
    );
    setState(() {
      _bookmarks = maps.map((m) => Bookmark.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteBookmark(int id) async {
    final db = await _dbService.database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.bookmark),
                  const SizedBox(width: 8),
                  const Text('书签列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _bookmarks.isEmpty
                      ? const Center(child: Text('暂无书签'))
                      : ListView.builder(
                          itemCount: _bookmarks.length,
                          itemBuilder: (context, index) {
                            final bookmark = _bookmarks[index];
                            return ListTile(
                              leading: const Icon(Icons.bookmark_border),
                              title: Text(bookmark.displayTitle),
                              subtitle: Text(bookmark.formattedCreatedAt),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteBookmark(bookmark.id!),
                              ),
                              onTap: () {
                                widget.onBookmarkTap(bookmark.position);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
