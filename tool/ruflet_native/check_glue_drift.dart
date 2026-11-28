// See check_glue_drift.sh. A glue file starts with header lines
//   // ruflet-native-glue: source=<path from the repository root>
//   // ruflet-native-glue: commit=<sha the copy was made from>
//   // ruflet-native-glue: replace=<old>=><new>      (applied in order)
// followed by further comment lines, one blank line, and the copied body.
import 'dart:io';

void main() {
  final glue = Directory('packages/ruflet/native/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => f.readAsStringSync().startsWith('// ruflet-native-glue:'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  var failures = 0;
  for (final file in glue) {
    final lines = file.readAsLinesSync();
    String? source;
    final replacements = <(String, String)>[];
    var i = 0;
    for (; i < lines.length && lines[i].startsWith('//'); i++) {
      const tag = '// ruflet-native-glue: ';
      if (!lines[i].startsWith(tag)) continue;
      final entry = lines[i].substring(tag.length);
      if (entry.startsWith('source=')) source = entry.substring(7);
      if (entry.startsWith('replace=')) {
        final rule = entry.substring(8);
        final arrow = rule.indexOf('=>');
        replacements.add((rule.substring(0, arrow), rule.substring(arrow + 2)));
      }
    }
    if (i < lines.length && lines[i].isEmpty) i++;
    final body = '${lines.sublist(i).join('\n')}\n';
    if (source == null || !File(source).existsSync()) {
      stderr.writeln('::error file=${file.path}::glue source $source not found');
      failures++;
      continue;
    }
    var expected = File(source).readAsStringSync();
    for (final (from, to) in replacements) {
      if (!expected.contains(from)) {
        stderr.writeln('::error file=${file.path}::"$from" no longer occurs in '
            '$source: update the glue and its header');
        failures++;
      }
      expected = expected.replaceAll(from, to);
    }
    if (expected != body) {
      stderr.writeln('::error file=${file.path}::glue differs from $source '
          'with its substitutions; copy the current source again');
      final tmp = Directory.systemTemp.createTempSync('glue');
      File('${tmp.path}/expected.dart').writeAsStringSync(expected);
      File('${tmp.path}/glue.dart').writeAsStringSync(body);
      final diff = Process.runSync(
          'diff', ['-u', '${tmp.path}/expected.dart', '${tmp.path}/glue.dart']);
      stderr.write(diff.stdout);
      tmp.deleteSync(recursive: true);
      failures++;
    } else {
      stdout.writeln('ok ${file.path} == $source');
    }
  }
  if (glue.isEmpty) stdout.writeln('no glue files');
  if (failures > 0) exit(1);
}
