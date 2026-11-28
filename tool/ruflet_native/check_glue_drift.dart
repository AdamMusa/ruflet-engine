// See check_glue_drift.sh. A glue file starts with a comment block holding
//   // ruflet-native-glue: source=<path from the repository root>
//   // ruflet-native-glue: commit=<sha the copy was made from>
//   // ruflet-native-glue: replace=<old>=><new>      (applied in order)
// among its comment lines, followed by one blank line and the copied body.
// Every lib/src/<feature>/*_service.dart is service glue (SPEC §2.3, §3.3)
// and must carry the header; any other file that carries it (code ported
// from an engine package) is checked too.
import 'dart:io';

const _tag = '// ruflet-native-glue: ';

/// The leading comment block of [lines].
Iterable<String> _header(List<String> lines) =>
    lines.takeWhile((line) => line.startsWith('//'));

bool _isServiceFile(String path) =>
    RegExp(r'lib/src/[a-z0-9_]+/[a-z0-9_]+_service\.dart$')
        .hasMatch(path.replaceAll(r'\', '/'));

void main() {
  final files = Directory('packages/ruflet/native/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  var failures = 0;
  final glue = <File>[];
  for (final file in files) {
    final tagged = _header(file.readAsLinesSync()).any((l) => l.startsWith(_tag));
    if (tagged) {
      glue.add(file);
    } else if (_isServiceFile(file.path)) {
      stderr.writeln('::error file=${file.path}::service glue without a '
          '"${_tag}source=" header in its leading comment block');
      failures++;
    }
  }
  for (final file in glue) {
    final lines = file.readAsLinesSync();
    String? source;
    final replacements = <(String, String)>[];
    var i = 0;
    for (; i < lines.length && lines[i].startsWith('//'); i++) {
      if (!lines[i].startsWith(_tag)) continue;
      final entry = lines[i].substring(_tag.length);
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
