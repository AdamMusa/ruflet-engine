// Values whose JSON type is not the one the renderer reads
// (AdamMusa/ruflet-engine#128). Ruby sends a Float wherever an app computes
// a number (`divisions: (max - min) / step` sends 10.0) and Rails HTML sends
// attribute strings, and the typed getters used to cast them, so the control
// became an ErrorWidget (a grey box in release). Each value now reads like
// its well-typed twin, or falls back to the prop's default with a
// debug-only message. Well-typed values read exactly as before.
//
// Also: a Material Tabs without `length` (Ruby does not require it) threw in
// `clamp(0, length - 1)`; and a Material TabBar with `padding` parsed the
// parsed EdgeInsets again.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _text(int id, String value) =>
    {'_c': 'Text', '_i': id, 'value': value};

Map<String, dynamic> _container(Map<String, dynamic> props) =>
    {'_c': 'Container', '_i': 1, 'content': _text(2, 'x'), ...props};

Map<String, dynamic> _textControl(Map<String, dynamic> props) =>
    {'_c': 'Text', '_i': 1, 'value': 'hello', ...props};

Map<String, dynamic> _slider(Map<String, dynamic> props) =>
    {'_c': 'Slider', '_i': 1, 'value': 5, 'min': 0, 'max': 10, ...props};

Map<String, dynamic> _textField(Map<String, dynamic> props) =>
    {'_c': 'TextField', '_i': 1, 'value': 'a', ...props};

Map<String, dynamic> _column(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 1,
      'controls': [_text(2, 'x'), _text(3, 'y')],
      ...props
    };

Map<String, dynamic> _checkbox(Map<String, dynamic> props) =>
    {'_c': 'Checkbox', '_i': 1, ...props};

Map<String, dynamic> _progressBar(Map<String, dynamic> props) =>
    {'_c': 'ProgressBar', '_i': 1, 'width': 200, ...props};

Map<String, dynamic> _tabs(Map<String, dynamic> props) => {
      '_c': 'Tabs',
      '_i': 1,
      'length': 2,
      'content': {
        '_c': 'TabBar',
        '_i': 2,
        'tabs': [
          {'_c': 'Tab', '_i': 3, 'label': 'a'},
          {'_c': 'Tab', '_i': 4, 'label': 'b'}
        ]
      },
      ...props
    };

/// What a case reads back from the rendered tree to show the value applied.
typedef _Probe = Object? Function(WidgetTester tester, HarnessDesign design);

Object? _width(WidgetTester tester, HarnessDesign design) =>
    tester.getSize(find.byType(ControlWidget).first).width;

Object? _opacity(WidgetTester tester, HarnessDesign design) {
  final found = find.byType(Opacity);
  return found.evaluate().isEmpty
      ? null
      : tester.widget<Opacity>(found.first).opacity;
}

Object? _textOffset(WidgetTester tester, HarnessDesign design) =>
    tester.getTopLeft(find.text('x')) -
    tester.getTopLeft(find.byType(ControlWidget).first);

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

Object? _maxLines(WidgetTester tester, HarnessDesign design) =>
    _paragraph(tester, 'hello').maxLines;

Object? _fontSize(WidgetTester tester, HarnessDesign design) =>
    _paragraph(tester, 'hello').text.style?.fontSize;

Object? _textColor(WidgetTester tester, HarnessDesign design) =>
    _paragraph(tester, 'hello').text.style?.color?.toARGB32();

Object? _divisions(WidgetTester tester, HarnessDesign design) => design ==
        HarnessDesign.ios
    ? tester.widget<CupertinoSlider>(find.byType(CupertinoSlider)).divisions
    : tester.widget<material.Slider>(find.byType(material.Slider)).divisions;

Object? _maxLength(WidgetTester tester, HarnessDesign design) =>
    design == HarnessDesign.ios
        ? tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .maxLength
        : tester
            .widget<material.TextField>(find.byType(material.TextField))
            .maxLength;

Object? _spacing(WidgetTester tester, HarnessDesign design) =>
    tester.getTopLeft(find.text('y')).dy -
    tester.getBottomLeft(find.text('x')).dy;

Object? _checked(WidgetTester tester, HarnessDesign design) => design ==
        HarnessDesign.ios
    ? tester.widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox)).value
    : tester.widget<material.Checkbox>(find.byType(material.Checkbox)).value;

/// Material paints the value; the Cupertino bar sizes a fill box by it.
Object? _progress(WidgetTester tester, HarnessDesign design) {
  if (design == HarnessDesign.android) {
    return tester
        .widget<material.LinearProgressIndicator>(
            find.byType(material.LinearProgressIndicator))
        .value;
  }
  final root = find.byType(ControlWidget).first;
  return [
    for (final element in find
        .descendant(of: root, matching: find.byWidgetPredicate((_) => true))
        .evaluate())
      if (element.renderObject case final RenderBox box) box.size.width
  ];
}

Object? _selectedTab(WidgetTester tester, HarnessDesign design) =>
    design == HarnessDesign.ios
        ? tester
            .widget<CupertinoSlidingSegmentedControl<int>>(
                find.byType(CupertinoSlidingSegmentedControl<int>))
            .groupValue
        : tester
            .widget<material.TabBar>(find.byType(material.TabBar))
            .controller!
            .index;

class _Case {
  const _Case(this.name, this.probe,
      {required this.value,
      required this.twin,
      required this.absent,
      this.reported = false,
      this.settle = true});

  final String name;
  final _Probe probe;

  /// Whether a debug message names the value (getters do; the shape
  /// parsers and colors do not know their control).
  final bool reported;

  /// False for a control that animates forever (an indeterminate bar).
  final bool settle;

  /// The wire with the wrongly typed value.
  final Map<String, dynamic> value;

  /// The well-typed wire it must render like, or null when it must render
  /// like [absent] (no reading: the prop's default).
  final Map<String, dynamic>? twin;

  /// The wire without the prop.
  final Map<String, dynamic> absent;
}

/// The 12 values of the audit table, then the fractional and unreadable
/// ones.
final _cases = <_Case>[
  _Case('container width "100"', _width,
      value: _container({'width': '100'}),
      twin: _container({'width': 100}),
      absent: _container({})),
  _Case('container opacity "0.5"', _opacity,
      value: _container({'opacity': '0.5'}),
      twin: _container({'opacity': 0.5}),
      absent: _container({})),
  _Case('container padding "10"', _textOffset,
      value: _container({'padding': '10'}),
      twin: _container({'padding': 10}),
      absent: _container({})),
  _Case('text max_lines 2.0', _maxLines,
      value: _textControl({'max_lines': 2.0}),
      twin: _textControl({'max_lines': 2}),
      absent: _textControl({})),
  _Case('text size "16"', _fontSize,
      value: _textControl({'size': '16'}),
      twin: _textControl({'size': 16}),
      absent: _textControl({})),
  _Case('slider divisions 10.0', _divisions,
      value: _slider({'divisions': 10.0}),
      twin: _slider({'divisions': 10}),
      absent: _slider({})),
  _Case('textfield max_length 10.0', _maxLength,
      value: _textField({'max_length': 10.0}),
      twin: _textField({'max_length': 10}),
      absent: _textField({})),
  _Case('column spacing "8"', _spacing,
      value: _column({'spacing': '8'}),
      twin: _column({'spacing': 8}),
      absent: _column({})),
  _Case('checkbox value "true"', _checked,
      value: _checkbox({'value': 'true'}),
      twin: _checkbox({'value': true}),
      absent: _checkbox({})),
  _Case('progress bar value "0.5"', _progress,
      value: _progressBar({'value': '0.5'}),
      twin: _progressBar({'value': 0.5}),
      absent: _progressBar({}),
      settle: false),
  _Case('tabs selected_index 1.0', _selectedTab,
      value: _tabs({'selected_index': 1.0}),
      twin: _tabs({'selected_index': 1}),
      absent: _tabs({})),
  // Already degraded gracefully; pinned so it stays that way.
  _Case('text color "not-a-color"', _textColor,
      value: _textControl({'color': 'not-a-color'}),
      twin: null,
      absent: _textControl({})),
  // A fractional Float rounds: float arithmetic such as (0.3 - 0) / 0.1
  // gives 2.9999999999999996 for what is meant to be 3.
  _Case('slider divisions 2.9999999999999996', _divisions,
      value: _slider({'divisions': (0.3 - 0) / 0.1}),
      twin: _slider({'divisions': 3}),
      absent: _slider({})),
  _Case('text max_lines 2.5', _maxLines,
      value: _textControl({'max_lines': 2.5}),
      twin: _textControl({'max_lines': 3}),
      absent: _textControl({})),
  _Case('text max_lines "2.0"', _maxLines,
      value: _textControl({'max_lines': '2.0'}),
      twin: _textControl({'max_lines': 2}),
      absent: _textControl({})),
  // No reading: the prop's default, with a debug message.
  _Case('container width "100px"', _width,
      value: _container({'width': '100px'}),
      twin: null,
      absent: _container({}),
      reported: true),
  _Case('text size "big"', _fontSize,
      value: _textControl({'size': 'big'}),
      twin: null,
      absent: _textControl({}),
      reported: true),
  _Case('checkbox value "yes"', _checked,
      value: _checkbox({'value': 'yes'}),
      twin: null,
      absent: _checkbox({}),
      reported: true),
  _Case('container padding "10px"', _textOffset,
      value: _container({'padding': '10px'}),
      twin: null,
      absent: _container({})),
];

/// The `Ruflet: ...` messages [body] prints through debugPrint.
Future<List<String>> _messages(Future<void> Function() body) async {
  final messages = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.startsWith('Ruflet: ')) {
      messages.add(message);
    }
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return messages;
}

/// Mounts [wire] and returns what [probe] reads, after checking nothing
/// threw and no ErrorWidget replaced a control.
Future<Object?> _render(WidgetTester tester, HarnessDesign design,
    Map<String, dynamic> wire, _Probe probe,
    {bool settle = true}) async {
  await mountWire(tester, design, wire, settle: settle);
  final error = tester.takeException();
  expect(error, isNull, reason: '$error');
  expect(find.byType(ErrorWidget), findsNothing);
  return probe(tester, design);
}

void _log(Map<String, Object?> data) {
  // One line per probe, so a run before and after the fix can be compared.
  // ignore: avoid_print
  print('TYPED ${jsonEncode(data)}');
}

Control _control(Map<String, dynamic> properties) => Control(
    id: 7,
    type: 'Text',
    properties: properties,
    backend: RufletBackend(
        pageUri: Uri.parse('ruflet://typed'),
        assetsDir: '',
        extensions: [],
        multiView: false));

void main() {
  for (final design in HarnessDesign.values) {
    for (final c in _cases) {
      testWidgets('${design.name} ${c.name}', (tester) async {
        // The well-typed renders first: their probes must not change.
        final twin = c.twin == null
            ? null
            : await _render(tester, design, c.twin!, c.probe, settle: c.settle);
        final absent =
            await _render(tester, design, c.absent, c.probe, settle: c.settle);
        _log({
          'design': design.name,
          'case': c.name,
          'twin': '$twin',
          'absent': '$absent',
        });
        Object? read;
        final messages = await _messages(() async {
          read =
              await _render(tester, design, c.value, c.probe, settle: c.settle);
        });
        _log({'design': design.name, 'case': c.name, 'read': '$read'});
        if (c.twin != null) {
          expect(read, twin, reason: 'reads like the well-typed value');
          expect(twin, isNot(absent), reason: 'the probe sees the prop');
          expect(messages, isEmpty);
        } else {
          expect(read, absent, reason: 'falls back to the default');
          expect(messages, hasLength(c.reported ? 1 : 0), reason: '$messages');
        }
      });
    }

    testWidgets('${design.name} an unreadable value is reported once',
        (tester) async {
      final messages = await _messages(() async {
        final m =
            await mountWire(tester, design, _container({'width': 'wide'}));
        m.control(1).update({'opacity': 0.9}, shouldNotify: true);
        await tester.pumpAndSettle();
      });
      expect(tester.takeException(), isNull);
      expect(messages, [
        'Ruflet: Container(1).width expects double, got String "wide"; '
            'using no value.'
      ]);
    });

    group('${design.name} Tabs without length', () {
      testWidgets('renders its content', (tester) async {
        await _render(tester, design,
            {'_c': 'Tabs', '_i': 1, 'content': _text(2, 'x')}, _width);
        expect(find.text('x'), findsOneWidget);
      });

      testWidgets('an empty data-driven tab set renders', (tester) async {
        // `tabs(length: items.size, ...)` with no items yet.
        await _render(
            tester,
            design,
            {
              '_c': 'Tabs',
              '_i': 1,
              'length': 0,
              'selected_index': 0,
              'content': {
                '_c': 'Column',
                '_i': 2,
                'controls': [
                  {'_c': 'Text', '_i': 3, 'value': 'title'},
                  {'_c': 'TabBar', '_i': 4, 'tabs': []},
                  {'_c': 'TabBarView', '_i': 5, 'controls': [], 'height': 100},
                ]
              }
            },
            _width);
        expect(find.text('title'), findsOneWidget);
      });

      testWidgets('a TabBar with tabs says length is missing', (tester) async {
        await _render(tester, design, _tabs({'length': null}), _width);
        if (design == HarnessDesign.android) {
          expect(find.text('TabBar has 2 tabs but Tabs.length is 0'),
              findsOneWidget);
        } else {
          // Cupertino draws the segments from the tabs it has.
          expect(find.text('a'), findsOneWidget);
          expect(find.text('b'), findsOneWidget);
        }
      });

      testWidgets('a TabBarView with pages says length is missing',
          (tester) async {
        await _render(
            tester,
            design,
            {
              '_c': 'Tabs',
              '_i': 1,
              'content': {
                '_c': 'TabBarView',
                '_i': 2,
                'height': 100,
                'controls': [_text(3, 'page a'), _text(4, 'page b')]
              }
            },
            _width);
        if (design == HarnessDesign.android) {
          expect(find.text('TabBarView has 2 controls but Tabs.length is 0'),
              findsOneWidget);
        } else {
          expect(find.text('page a'), findsOneWidget);
        }
      });

      testWidgets('tabs that arrive later work', (tester) async {
        final m = await mountWire(tester, design, {
          '_c': 'Tabs',
          '_i': 1,
          'length': 0,
          'on_change': true,
          'content': {'_c': 'TabBar', '_i': 2, 'tabs': []}
        });
        expect(tester.takeException(), isNull);
        m.control(1).update({'length': 2}, shouldNotify: true);
        m.control(2).update({
          'tabs': [
            {'_c': 'Tab', '_i': 3, 'label': 'a'},
            {'_c': 'Tab', '_i': 4, 'label': 'b'}
          ],
          'on_click': true,
        }, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        m.backend.sent.clear();
        await tester.tap(find.text('b'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final events = [
          for (final s in m.backend.sent)
            if (s.props == null) '${s.id}:${s.name}:${s.data}'
        ];
        expect(events, contains('2:click:1'));
        expect(_selectedTab(tester, design), 1);
      });

      testWidgets('tabs that go away leave no error', (tester) async {
        final m = await mountWire(tester, design, _tabs({}));
        expect(tester.takeException(), isNull);
        m.control(1).update({'length': 0}, shouldNotify: true);
        m.control(2).update({'tabs': []}, shouldNotify: true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      });
    });
  }

  testWidgets('a Material TabBar applies its padding', (tester) async {
    for (final padding in <Object>[
      4,
      {'left': 4, 'right': 6}
    ]) {
      await _render(
          tester,
          HarnessDesign.android,
          _tabs({
            'content': {
              ..._tabs({})['content'] as Map<String, dynamic>,
              'padding': padding,
            }
          }),
          _width);
      expect(
          tester.widget<material.TabBar>(find.byType(material.TabBar)).padding,
          padding == 4
              ? const EdgeInsets.all(4)
              : const EdgeInsets.only(left: 4, right: 6));
    }
  });

  group('Control.get', () {
    test('well-typed values are returned unchanged', () {
      final c = _control({
        'i': 3,
        'd': 2.5,
        'w': 4.0,
        'b': false,
        's': 'text',
        'm': {'all': 2},
        'l': [1, 2],
      });
      expect(c.get<int>('i'), same(3));
      expect(c.getInt('i'), 3);
      expect(c.getDouble('d'), 2.5);
      expect(c.getDouble('w'), 4.0);
      expect(c.getDouble('i'), 3.0);
      expect(c.getDouble('i'), isA<double>());
      expect(c.getBool('b'), false);
      expect(c.getString('s'), 'text');
      expect(c.getString('i'), '3');
      expect(c.getString('d'), '2.5');
      expect(c.get<Map>('m'), {'all': 2});
      expect(c.get('l'), [1, 2]);
      expect(c.getInt('missing', 9), 9);
      expect(c.getDouble('missing'), isNull);
    });

    test('an int prop reads a Float or a numeric string', () {
      final c = _control({
        'whole': 10.0,
        'drift': (0.3 - 0) / 0.1,
        'half': 2.5,
        'negative': -1.0,
        'text': '2',
        'padded': ' 12 ',
        'decimal': '2.0',
        'nan': double.nan,
        'infinite': double.infinity,
        'word': 'two',
        'flag': true,
      });
      expect(c.getInt('whole'), 10);
      expect(c.getInt('drift'), 3);
      expect(c.getInt('half'), 3);
      expect(c.getInt('negative'), -1);
      expect(c.getInt('text'), 2);
      expect(c.getInt('padded'), 12);
      expect(c.getInt('decimal'), 2);
      expect(c.getInt('nan', 5), 5);
      expect(c.getInt('infinite', 5), 5);
      expect(c.getInt('word', 5), 5);
      expect(c.getInt('flag'), isNull);
    });

    test('a double prop reads a numeric string', () {
      final c = _control({
        'text': '16',
        'padded': ' 0.5 ',
        'exponent': '1e3',
        'inf': 'inf',
        'px': '100px',
        'nan': 'NaN',
        'flag': true,
      });
      expect(c.getDouble('text'), 16.0);
      expect(c.getDouble('padded'), 0.5);
      expect(c.getDouble('exponent'), 1000.0);
      expect(c.getDouble('inf'), double.infinity);
      expect(c.getDouble('px', 1), 1);
      expect(c.getDouble('nan', 1), 1);
      expect(c.getDouble('flag'), isNull);
    });

    test('a bool prop reads "true" and "false" only', () {
      final c = _control({
        'yes': 'true',
        'upper': 'TRUE',
        'no': ' false ',
        'word': 'yes',
        'one': 1,
        'visible': 'false',
        'disabled': 'true',
      });
      expect(c.getBool('yes'), true);
      expect(c.getBool('upper'), true);
      expect(c.getBool('no'), false);
      expect(c.getBool('word', true), true);
      expect(c.getBool('word'), isNull);
      expect(c.getBool('one', false), false);
      expect(c.visible, false);
      expect(c.disabled, true);
    });
  });

  group('shape parsers', () {
    test('padding and margin read a numeric string', () {
      expect(parseEdgeInsets('10'), const EdgeInsets.all(10));
      expect(parsePadding(' 4.5 '), const EdgeInsets.all(4.5));
      expect(parseMargin('8'), const EdgeInsets.all(8));
      expect(
          parseEdgeInsetsDirectional('6'), const EdgeInsetsDirectional.all(6));
      expect(parseEdgeInsets('10px', EdgeInsets.zero), EdgeInsets.zero);
      expect(parseEdgeInsets('inf'), isNull);
      expect(parseEdgeInsets([1, 2]), isNull);
      expect(parseEdgeInsetsDirectional('wide'), isNull);
    });

    test('padding shapes Ruby sends read as before', () {
      expect(parseEdgeInsets(10), const EdgeInsets.all(10));
      expect(parseEdgeInsets(2.5), const EdgeInsets.all(2.5));
      expect(parseEdgeInsets(double.infinity),
          const EdgeInsets.all(double.infinity));
      expect(parseEdgeInsets({'all': 8}), const EdgeInsets.all(8));
      expect(parseEdgeInsets({'left': 1, 'top': '2', 'right': 3, 'bottom': 4}),
          const EdgeInsets.fromLTRB(1, 2, 3, 4));
      expect(parseEdgeInsetsDirectional({'left': 1, 'right': 2}),
          const EdgeInsetsDirectional.fromSTEB(1, 0, 2, 0));
      expect(parseEdgeInsets(null, EdgeInsets.zero), EdgeInsets.zero);
    });

    test('border radius reads a numeric string', () {
      expect(parseBorderRadius('8'), BorderRadius.circular(8));
      expect(parseBorderRadius(' 2.5 '), BorderRadius.circular(2.5));
      expect(parseBorderRadius('8px', BorderRadius.zero), BorderRadius.zero);
      expect(parseBorderRadius('inf'), isNull);
      expect(parseBorderRadius([1]), isNull);
    });

    test('border radius shapes Ruby sends read as before', () {
      expect(parseBorderRadius(8), BorderRadius.circular(8));
      expect(parseBorderRadius(1.5), BorderRadius.circular(1.5));
      expect(parseBorderRadius({'all': 8.0}), BorderRadius.circular(8));
      expect(parseBorderRadius({'top_left': 4}),
          const BorderRadius.only(topLeft: Radius.circular(4)));
      expect(parseBorderRadius(null), isNull);
    });
  });
}
