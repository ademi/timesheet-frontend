const taskTitlePresets = [
  'Personal care',
  'Community access',
  'Domestic assistance',
  'Transport',
];

const taskTitlePresetOther = 'Other…';

List<String> parseTaskTitles(String text) =>
    text
        .split('\n')
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toList();

String appendTaskTitleLine(String current, String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return current;
  final trimmedCurrent = current.trim();
  return trimmedCurrent.isEmpty ? trimmed : '$trimmedCurrent\n$trimmed';
}
