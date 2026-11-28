// Generates the jnigen bindings of ruflet_native.
//
//   cd tool/ruflet_native/bindings && dart run generate.dart [name ...]
//
// - `shared` (shared.dart): the shared Android layer's bindings, written to
//   packages/ruflet/native/lib/src/ffi/android/bindings/shared.g.dart.
// - every `<feature>.yaml` next to this file: a feature's own jnigen config
//   (jnigen's YAML format, output under lib/src/<feature>/). Found by glob,
//   so a feature PR only adds its YAML file.
//
// The classpath comes from the generated example app, which must have been
// built once: `../prepare_example.sh example` then
// `(cd ../example && flutter build apk --debug)`.
import 'dart:io';

import 'package:jnigen/jnigen.dart';

import 'shared.dart';

Future<void> main(List<String> args) async {
  final here = Platform.script.resolve('./');
  final packageRoot = here.resolve('../../../packages/ruflet/native/');
  final exampleRoot = here.resolve('../example/');
  final yamlConfigs = {
    for (final file in Directory.fromUri(here).listSync())
      if (file is File && file.path.endsWith('.yaml') &&
          !file.path.endsWith('pubspec.yaml'))
        file.uri.pathSegments.last.replaceAll('.yaml', ''): file,
  };
  final names = args.isNotEmpty ? args : ['shared', ...yamlConfigs.keys];
  for (final name in names) {
    stdout.writeln('jnigen: $name');
    if (name == 'shared') {
      await generateJniBindings(sharedConfig(packageRoot, exampleRoot));
      continue;
    }
    final yaml = yamlConfigs[name];
    if (yaml == null) {
      stderr.writeln('unknown binding config: $name');
      exitCode = 2;
      return;
    }
    final result = await Process.run(
        Platform.resolvedExecutable, ['run', 'jnigen', '--config', yaml.path],
        workingDirectory: here.toFilePath());
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      exitCode = result.exitCode;
      return;
    }
  }
}
