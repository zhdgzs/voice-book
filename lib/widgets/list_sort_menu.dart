import 'package:flutter/material.dart';
import '../utils/list_sort.dart';

/// 列表排序菜单；方向由单独菜单项切换。
class ListSortMenu extends StatelessWidget {
  final ListSortField field;
  final bool ascending;
  final bool isBookList;
  final void Function(ListSortField, bool) onChanged;

  const ListSortMenu({
    super.key,
    required this.field,
    required this.ascending,
    required this.isBookList,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '排序',
      icon: const Icon(Icons.sort),
      onSelected: (value) {
        if (value == 'direction') {
          onChanged(field, !ascending);
        } else {
          onChanged(value == 'name' ? ListSortField.name : ListSortField.importTime,
              ascending);
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'name',
          checked: field == ListSortField.name,
          child: Text(isBookList ? '按书名' : '按文件名'),
        ),
        CheckedPopupMenuItem(
          value: 'time',
          checked: field == ListSortField.importTime,
          child: const Text('按导入时间'),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: 'direction',
          checked: ascending,
          child: Text(ascending ? '升序' : '降序'),
        ),
      ],
    );
  }
}
