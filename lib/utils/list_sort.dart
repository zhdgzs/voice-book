import '../models/audio_file.dart';
import '../models/book.dart';

enum ListSortField { name, importTime }

/// 数字片段按数值比较，同名时由调用方提供稳定次序。
int naturalCompare(String a, String b) {
  final segments = RegExp(r'(\d+)|(\D+)');
  final left = segments.allMatches(a).map((m) => m.group(0)!).toList();
  final right = segments.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final aNumber = int.tryParse(left[i]);
    final bNumber = int.tryParse(right[i]);
    final comparison = aNumber != null && bNumber != null
        ? aNumber.compareTo(bNumber)
        : left[i].toLowerCase().compareTo(right[i].toLowerCase());
    if (comparison != 0) return comparison;
  }
  return left.length.compareTo(right.length);
}

List<T> _sort<T>(List<T> items, String Function(T) name, int Function(T) time,
    int Function(T) id, ListSortField field, bool ascending) {
  final result = List<T>.from(items);
  result.sort((a, b) {
    final primary = field == ListSortField.name
        ? naturalCompare(name(a), name(b))
        : time(a).compareTo(time(b));
    final secondary = naturalCompare(name(a), name(b));
    final comparison = primary != 0 ? primary : secondary != 0 ? secondary : id(a).compareTo(id(b));
    return ascending ? comparison : -comparison;
  });
  return result;
}

List<Book> sortBooks(List<Book> books, ListSortField field, bool ascending) =>
    _sort(books, (b) => b.title, (b) => b.createdAt, (b) => b.id ?? 0,
        field, ascending);

List<AudioFile> sortAudioFiles(
        List<AudioFile> files, ListSortField field, bool ascending) =>
    _sort(files, (f) => f.fileName, (f) => f.createdAt, (f) => f.id ?? 0,
        field, ascending);
