/// Case-insensitive, trimmed string compare for people / place / label lists.
int compareNames(String? a, String? b) =>
    (a ?? '').trim().toLowerCase().compareTo((b ?? '').trim().toLowerCase());

/// Returns a new list sorted alphabetically by [nameOf].
List<T> sortedByName<T>(Iterable<T> items, String? Function(T item) nameOf) {
  final list = List<T>.of(items);
  list.sort((a, b) => compareNames(nameOf(a), nameOf(b)));
  return list;
}
