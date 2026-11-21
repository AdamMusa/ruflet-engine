// Ruby's `page_transitions` theme keys select Flutter page transition
// builders. Flutter 3.44 moved CupertinoPageTransitionsBuilder from
// material.dart to cupertino.dart, so the engine must compile on both sides
// of that move and still hand Flutter the very same builder.
//
// This file imports both libraries, as only a test may: on 3.41 the class
// comes from material.dart, on 3.44 and later from cupertino.dart.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

/// Flutter names that material.dart exported on the pinned Flutter (3.41) and
/// only cupertino.dart exports on current stable. An engine library imports
/// one design library, never both (test/architecture), so a library naming
/// one of these compiles on only one side of the move.
const movedFromMaterialToCupertino = ['CupertinoPageTransitionsBuilder'];

Iterable<File> engineLibraries() => Directory.current.parent
    .listSync()
    .whereType<Directory>()
    .map((package) => Directory('${package.path}/lib'))
    .where((lib) => lib.existsSync())
    .expand((lib) => lib.listSync(recursive: true))
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

Future<void> pushDetail(WidgetTester tester, Map<String, dynamic> value) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigator,
    theme: ThemeData(
      platform: TargetPlatform.iOS,
      pageTransitionsTheme: parsePageTransitions(value),
    ),
    home: const Text('home'),
  ));
  navigator.currentState!
      .push(MaterialPageRoute<void>(builder: (_) => const Text('detail')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  test('no engine library names a class Flutter moved out of material.dart',
      () {
    final offenders = <String>[];
    for (final file in engineLibraries()) {
      final source = withoutComments(file.readAsStringSync());
      for (final name in movedFromMaterialToCupertino) {
        if (RegExp('\\b$name\\b').hasMatch(source)) {
          final path =
              file.path.substring(Directory.current.parent.path.length + 1);
          offenders.add('$path: $name');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'These fail to compile on Flutter 3.44 and later. Take the '
            'builder from a Material default such as '
            'const PageTransitionsTheme().builders instead.');
  });

  test('"cupertino" selects the same const builder Flutter itself uses', () {
    final builder = parseTransitionsBuilder('cupertino');

    expect(builder, isA<CupertinoPageTransitionsBuilder>());
    expect(builder, same(const CupertinoPageTransitionsBuilder()));
  });

  test('page_transitions keeps its per-platform defaults', () {
    final theme = parsePageTransitions({})!;

    expect(theme.builders[TargetPlatform.iOS],
        same(const CupertinoPageTransitionsBuilder()));
    expect(theme.builders[TargetPlatform.android],
        isA<FadeUpwardsPageTransitionsBuilder>());
    expect(theme.builders[TargetPlatform.linux],
        isA<ZoomPageTransitionsBuilder>());
    expect(theme.builders[TargetPlatform.macOS],
        isA<ZoomPageTransitionsBuilder>());
    expect(theme.builders[TargetPlatform.windows],
        isA<ZoomPageTransitionsBuilder>());
  });

  test('page_transitions maps each platform key Ruby sends', () {
    final theme = parsePageTransitions({
      'android': 'cupertino',
      'ios': 'zoom',
      'linux': 'fade_upwards',
      'macos': 'cupertino',
      'windows': 'none',
    })!;

    expect(theme.builders[TargetPlatform.android],
        same(const CupertinoPageTransitionsBuilder()));
    expect(
        theme.builders[TargetPlatform.iOS], isA<ZoomPageTransitionsBuilder>());
    expect(theme.builders[TargetPlatform.linux],
        isA<FadeUpwardsPageTransitionsBuilder>());
    expect(theme.builders[TargetPlatform.macOS],
        same(const CupertinoPageTransitionsBuilder()));
    expect(theme.builders[TargetPlatform.windows],
        isA<NoPageTransitionsBuilder>());
  });

  testWidgets('a Material route on iOS slides in with the Cupertino transition',
      (tester) async {
    await pushDetail(tester, {'ios': 'cupertino'});

    expect(find.byType(CupertinoPageTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('another iOS builder replaces the Cupertino transition',
      (tester) async {
    await pushDetail(tester, {'ios': 'zoom'});

    expect(find.byType(CupertinoPageTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
  });
}
