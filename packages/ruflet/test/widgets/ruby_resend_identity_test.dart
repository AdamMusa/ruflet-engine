// What a control keeps when Ruby re-sends it.
//
// Ruby re-sends a parent's whole children list on most updates
// (`col.controls << x; page.update` sends [[0],[0,0,"controls",[...]]] with
// every child), the page's `views` on every `page.add`, and the whole
// services list when a service is added or removed. The client builds a new
// Control object for each re-sent child, with the same id, while Flutter
// keeps the existing States. The session tests replay the exact messages
// ruflet's Page sends for those updates (captured from ruflet main) and pin:
// - Ruby's invokes on a re-sent control still reach its renderer (they
//   failed with "no handler ... is registered", and a re-sent service's
//   timed out);
// - every stateful control moves its invoke listener to the new object and
//   leaves none on the old one, also when Ruby puts a new control in the
//   same slot;
// - a scroll-keyed control keeps its state, focus and GlobalKey when its
//   parent rebuilds.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/protocol/message.dart';
import 'package:ruflet/src/services/service_registry.dart';

import '../support/control_harness.dart';

class _RecordingChannel implements RufletBackendChannel {
  _RecordingChannel(this.onMessage);

  final RufletBackendChannelOnMessageCallback onMessage;
  final sent = <Message>[];

  @override
  Future connect() async {}

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 500;

  @override
  void send(Message message) => sent.add(message);

  @override
  void disconnect() {}
}

class _SessionBackend extends RufletBackend {
  _SessionBackend(TargetPlatform design, {super.channelBuilder})
      : super(
            pageUri: Uri.parse('ruflet://resend-identity'),
            assetsDir: '',
            extensions: [],
            multiView: false) {
    platform = design;
    isLoading = false;
  }
}

/// A connected session: Ruby's messages go in through the real backend and
/// the replies the client sends back are recorded.
class _Session {
  _Session(this.backend, this.channel);

  final _SessionBackend backend;
  final _RecordingChannel channel;

  /// Sends Ruby's patch_control for control [id].
  void patch(int id, List<dynamic> patch) => channel.onMessage(Message(
      action: MessageAction.patchControl,
      payload: {'id': id, 'patch': patch}));

  /// Sends Ruby's invoke_control_method, with Ruby's default 10 s timeout
  /// (the tests never advance fake time that far).
  void invoke(int id, String name, [Object? args]) =>
      channel.onMessage(Message(
          action: MessageAction.invokeControlMethod,
          payload: {
            'control_id': id,
            'call_id': 'call_${id}_$name',
            'name': name,
            'args': args,
            'timeout': 10,
          }));

  /// The replies to invokes, in the order sent.
  List<Map> get replies => [
        for (final message in channel.sent)
          if (message.action == MessageAction.invokeControlMethod)
            message.payload as Map
      ];
}

/// The page patch Ruby's first `page.add` sends, with [controls] in View 20.
List<dynamic> _firstPagePatch(List<Map<String, dynamic>> controls) => [
      [0],
      [
        0,
        0,
        'views',
        [_view(controls)]
      ],
      [0, 0, 'route', '/'],
      [
        0,
        0,
        'window',
        {'_c': 'Window', '_i': 2}
      ],
      [
        0,
        0,
        '_overlay',
        {'_c': 'Overlay', '_i': 90, 'controls': []}
      ],
      [
        0,
        0,
        '_services',
        {
          '_c': 'ServiceRegistry',
          '_i': 91,
          '_services': [],
          '_internals': {'uid': 'u1'}
        }
      ],
      [
        0,
        0,
        '_dialogs',
        {'_c': 'Dialogs', '_i': 92, 'controls': []}
      ],
    ];

Map<String, dynamic> _view(List<Map<String, dynamic>> controls) => {
      '_c': 'View',
      '_i': 20,
      'route': '/',
      '_internals': {'host_expanded': true},
      'controls': controls,
    };

Future<_Session> _connect(WidgetTester tester, TargetPlatform design,
    List<Map<String, dynamic>> controls) async {
  late _RecordingChannel channel;
  final backend = _SessionBackend(design,
      channelBuilder: (
              {required address,
              required args,
              required forcePyodide,
              required onDisconnect,
              required onMessage}) =>
          channel = _RecordingChannel(onMessage));
  await backend.connect();
  final session = _Session(backend, channel);
  session.patch(1, _firstPagePatch(controls));
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend, child: ControlWidget(control: backend.page)));
  await tester.pumpAndSettle();
  return session;
}

/// Sends each invoke and lets its handler finish, then returns the replies.
Future<List<Map>> _invokeAll(WidgetTester tester, _Session session,
    List<(int, String, Object?)> calls) async {
  session.channel.sent.clear();
  for (final (id, name, args) in calls) {
    session.invoke(id, name, args);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
  return session.replies;
}

Matcher _answered(int id) => isA<Map>()
    .having((r) => r['control_id'], 'control_id', id)
    .having((r) => r['error'], 'error', isNull);

Map<String, dynamic> _textField(int id) =>
    {'_c': 'TextField', '_i': id, 'value': 'a'};

Map<String, dynamic> _text(int id, String value) =>
    {'_c': 'Text', '_i': id, 'value': value};

/// Column 100 as Ruby serializes `column(controls: [tf, list_view, tabs])`.
List<Map<String, dynamic>> _columnChildren({bool appended = false}) => [
      _textField(101),
      {
        '_c': 'ListView',
        '_i': 102,
        'build_controls_on_demand': true,
        'divider_thickness': 0,
        'first_item_prototype': false,
        'height': 100,
        'horizontal': false,
        'reverse': false,
        'spacing': 0,
        'controls': [for (var i = 0; i < 30; i++) _text(103 + i, 'item $i')],
      },
      {
        '_c': 'Tabs',
        '_i': 133,
        'length': 2,
        'selected_index': 0,
        'content': {
          '_c': 'TabBar',
          '_i': 134,
          'tabs': [
            {'_c': 'Tab', '_i': 135, 'label': 'a'},
            {'_c': 'Tab', '_i': 136, 'label': 'b'},
          ]
        }
      },
      if (appended) _text(140, 'new'),
    ];

Map<String, dynamic> _column({bool appended = false}) => {
      '_c': 'Column',
      '_i': 100,
      '_internals': {'host_expanded': true},
      'controls': _columnChildren(appended: appended),
    };

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

/// A stateful control in a Column, as Ruby sends it. [build] takes the id so
/// the same control can be re-sent with a new id.
typedef _Node = Map<String, dynamic> Function(int id);

Map<String, dynamic> _content(int id) => _text(id + 1000, 'content');

/// Every legacy-pattern control whose renderer answers Ruby's invokes from a
/// State (InvokeMethodListenerMixin), on both designs.
final Map<String, _Node> _statefulControls = {
  'TextField': (id) => {'_c': 'TextField', '_i': id, 'value': 'a'},
  'ListView': (id) => {
        '_c': 'ListView',
        '_i': id,
        'height': 100,
        'controls': [for (var i = 0; i < 5; i++) _text(id + 1000 + i, '$i')],
      },
  'GridView': (id) => {
        '_c': 'GridView',
        '_i': id,
        'height': 100,
        'runs_count': 2,
        'controls': [for (var i = 0; i < 5; i++) _text(id + 1000 + i, '$i')],
      },
  'scrolling Column': (id) => {
        '_c': 'Column',
        '_i': id,
        'height': 100,
        'scroll': 'auto',
        'controls': [for (var i = 0; i < 5; i++) _text(id + 1000 + i, '$i')],
      },
  'Tabs': (id) => {
        '_c': 'Tabs',
        '_i': id,
        'length': 2,
        'selected_index': 0,
        'content': {
          '_c': 'TabBar',
          '_i': id + 1000,
          'tabs': [
            {'_c': 'Tab', '_i': id + 1001, 'label': 'a'},
            {'_c': 'Tab', '_i': id + 1002, 'label': 'b'},
          ]
        }
      },
  'PageView': (id) => {
        '_c': 'PageView',
        '_i': id,
        'height': 100,
        'controls': [_text(id + 1000, 'p1'), _text(id + 1001, 'p2')],
      },
  'Dropdown': (id) => {
        '_c': 'Dropdown',
        '_i': id,
        'options': [
          {'_c': 'DropdownOption', '_i': id + 1000, 'key': 'a', 'text': 'A'}
        ],
      },
  'DropdownM2': (id) => {
        '_c': 'DropdownM2',
        '_i': id,
        'options': [
          {'_c': 'DropdownOption', '_i': id + 1000, 'key': 'a', 'text': 'A'}
        ],
      },
  'SearchBar': (id) => {'_c': 'SearchBar', '_i': id},
  'CarouselView': (id) => {
        '_c': 'CarouselView',
        '_i': id,
        'height': 100,
        'item_extent': 100,
        'controls': [_text(id + 1000, 'c1'), _text(id + 1001, 'c2')],
      },
  'Dismissible': (id) =>
      {'_c': 'Dismissible', '_i': id, 'content': _content(id)},
  'InteractiveViewer': (id) => {
        '_c': 'InteractiveViewer',
        '_i': id,
        'width': 100,
        'height': 100,
        'content': _content(id),
      },
  'KeyboardListener': (id) =>
      {'_c': 'KeyboardListener', '_i': id, 'content': _content(id)},
  'Canvas': (id) =>
      {'_c': 'Canvas', '_i': id, 'width': 50, 'height': 50, 'shapes': []},
  'ContextMenu': (id) =>
      {'_c': 'ContextMenu', '_i': id, 'content': _content(id)},
  'Screenshot': (id) =>
      {'_c': 'Screenshot', '_i': id, 'content': _content(id)},
  'Pagelet': (id) => {
        '_c': 'Pagelet',
        '_i': id,
        'width': 200,
        'height': 200,
        'content': _content(id),
      },
  'DraggableScrollableSheet': (id) => {
        '_c': 'DraggableScrollableSheet',
        '_i': id,
        'content': {
          '_c': 'ListView',
          '_i': id + 1000,
          'controls': [_text(id + 1001, 'row')],
        },
      },
};

/// Fake time for renderers with an animation that never settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A test service: answers `ping`, counts its lifecycle calls.
class _PingService extends RufletService {
  _PingService({required super.control});

  int inits = 0;
  int updates = 0;
  int disposes = 0;
  final updatedValues = <Object?>[];

  @override
  void init() {
    super.init();
    inits++;
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void update() {
    updates++;
    updatedValues.add(control.get('value'));
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async =>
      name == 'ping' ? 'pong ${control.get('value')}' : null;

  @override
  void dispose() {
    disposes++;
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }
}

class _PingExtension extends RufletExtension {
  final services = <int, _PingService>{};

  @override
  RufletService? createService(Control control) {
    if (control.type != 'Ping') return null;
    return services[control.id] = _PingService(control: control);
  }
}

void main() {
  for (final design in [TargetPlatform.android, TargetPlatform.iOS]) {
    final d = design.name;

    // Ruby: tf = text_field(value: "a"); page.add(tf); page.add(text("second"))
    // then tf.focus and page.close_drawer. The second add re-sends `views`.
    testWidgets('$d invokes reach a TextField and its View after a second '
        'page.add', (tester) async {
      final session = await _connect(tester, design, [_textField(100)]);
      final stateBefore = tester.state(find.byType(EditableText));

      session.patch(1, [
        [0],
        [
          0,
          0,
          'views',
          [
            _view([_textField(100), _text(104, 'second')])
          ]
        ],
        [0, 0, 'route', '/'],
        [
          0,
          0,
          'window',
          {'_c': 'Window', '_i': 2}
        ],
      ]);
      await tester.pumpAndSettle();
      expect(identical(stateBefore, tester.state(find.byType(EditableText))),
          isTrue,
          reason: 'the re-sent TextField keeps its state');

      final replies = await _invokeAll(tester, session, [
        (100, 'focus', const {}),
        (20, 'close_drawer', null),
      ]);
      expect(replies, [_answered(100), _answered(20)]);
      expect(_editable(tester).focusNode.hasFocus, isTrue);
    });

    // Ruby: col = column(controls: [tf, list_view, tabs]); page.add(col);
    // col.controls << text("new"); page.update; then each control's method.
    testWidgets('$d invokes reach the children of a Column Ruby appended to',
        (tester) async {
      final session = await _connect(tester, design, [_column()]);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final stateBefore = tester.state(find.byType(EditableText));

      session.patch(100, [
        [0],
        [0, 0, 'controls', _columnChildren(appended: true)],
      ]);
      await tester.pumpAndSettle();
      expect(find.text('new'), findsOneWidget);
      expect(identical(stateBefore, tester.state(find.byType(EditableText))),
          isTrue);
      expect(_editable(tester).focusNode.hasFocus, isTrue,
          reason: 'appending after a focused field keeps its focus');

      final replies = await _invokeAll(tester, session, [
        (101, 'blur', const {}),
        (101, 'focus', const {}),
        (102, 'scroll_to', {'offset': 40}),
        (133, 'move_to', {'index': 1}),
      ]);
      expect(replies,
          [_answered(101), _answered(101), _answered(102), _answered(133)]);
      expect(_editable(tester).focusNode.hasFocus, isTrue);
      expect(
          tester
              .state<ScrollableState>(find
                  .ancestor(
                      of: find.text('item 0', skipOffstage: false),
                      matching: find.byType(Scrollable))
                  .first)
              .position
              .pixels,
          40);
      expect(session.backend.controlsIndex.get(133)!.get('selected_index'), 1);
    });

    // Ruby: clip = page.clipboard; clip.get; page.haptic_feedback; clip.get.
    // Adding the second service re-sends the whole services list.
    testWidgets('$d a service still answers after Ruby adds another service',
        (tester) async {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'copied'};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final session = await _connect(tester, design, [_text(100, 'hi')]);

      session.patch(91, [
        [0],
        [
          0,
          0,
          '_services',
          [
            {'_c': 'Clipboard', '_i': 104}
          ]
        ],
      ]);
      await tester.pump();
      var replies = await _invokeAll(tester, session, [(104, 'get', null)]);
      expect(replies, [_answered(104)]);
      expect(replies.single['result'], 'copied');

      session.patch(91, [
        [0],
        [
          0,
          0,
          '_services',
          [
            {'_c': 'Clipboard', '_i': 104},
            {'_c': 'HapticFeedback', '_i': 105},
          ]
        ],
      ]);
      await tester.pump();
      replies = await _invokeAll(tester, session, [
        (104, 'get', null),
        (105, 'light_impact', null),
      ]);
      expect(replies, [_answered(104), _answered(105)]);
      expect(replies.first['result'], 'copied');
    });

    group('$d a re-sent stateful control keeps its invoke listener', () {
      for (final MapEntry(key: name, value: node)
          in _statefulControls.entries) {
        for (final newId in [false, true]) {
          final how = newId
              ? 'Ruby puts a new $name in its slot'
              : 'Ruby re-sends the $name';
          testWidgets(how, (tester) async {
            final m = await mountWire(
                tester,
                HarnessDesign.values.firstWhere((h) => h.platform == design),
                {
                  '_c': 'Column',
                  '_i': 1,
                  'controls': [node(2)]
                },
                surface: const Size(800, 800),
                settle: false);
            await _frames(tester);
            final before = m.control(2);
            final listeners = before.debugInvokeMethodListenerCount;
            expect(listeners, greaterThan(0),
                reason: '$name answers invokes from a State');

            final id = newId ? 3 : 2;
            m.control(1).applyPatch([
              [0],
              [
                0,
                0,
                'controls',
                [node(id)]
              ],
            ], m.backend);
            await _frames(tester);
            final after = m.control(id);
            expect(identical(after, before), isFalse);
            expect(after.debugInvokeMethodListenerCount, listeners,
                reason: 'the listener moved to the object Ruby invokes');
            expect(before.debugInvokeMethodListenerCount, 0,
                reason: 'nothing is left on the replaced object');
            expect(after.isAttached, isTrue);
            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    group('$d a scroll-keyed control', () {
      Map<String, dynamic> keyedField() => {
            '_c': 'TextField',
            '_i': 2,
            'value': 'scroll-keyed',
            'key': {'_type': 'scroll', 'value': 'k1'},
          };

      Future<HarnessMount> mountFocused(WidgetTester tester) async {
        final m = await mountWire(
            tester,
            HarnessDesign.values.firstWhere((h) => h.platform == design),
            {
              '_c': 'Column',
              '_i': 1,
              'controls': [keyedField()]
            });
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        expect(_editable(tester).focusNode.hasFocus, isTrue);
        return m;
      }

      testWidgets('keeps its state, focus and GlobalKey when Ruby re-sends '
          'its parent', (tester) async {
        final m = await mountFocused(tester);
        final state = tester.state(find.byType(EditableText));
        final key = m.backend.globalKeys['k1'];

        m.control(1).applyPatch([
          [0],
          [
            0,
            0,
            'controls',
            [keyedField(), _text(3, 'appended')]
          ],
        ], m.backend);
        await tester.pumpAndSettle();
        expect(find.text('appended'), findsOneWidget);
        expect(identical(state, tester.state(find.byType(EditableText))),
            isTrue);
        expect(_editable(tester).focusNode.hasFocus, isTrue);
        expect(identical(m.backend.globalKeys['k1'], key), isTrue);
        expect(m.backend.globalKeys['k1']!.currentContext, isNotNull);
      });

      testWidgets('keeps its state when its parent changes a property',
          (tester) async {
        final m = await mountFocused(tester);
        final state = tester.state(find.byType(EditableText));

        m.control(1).applyPatch([
          [0],
          [0, 0, 'spacing', 24],
        ], m.backend);
        await tester.pumpAndSettle();
        expect(identical(state, tester.state(find.byType(EditableText))),
            isTrue);
        expect(_editable(tester).focusNode.hasFocus, isTrue);
      });

      testWidgets('gets a new GlobalKey when Ruby changes the key',
          (tester) async {
        final m = await mountFocused(tester);
        final key = m.backend.globalKeys['k1'];

        m.control(2).applyPatch([
          [0],
          [
            0,
            0,
            'key',
            {'_type': 'scroll', 'value': 'k2'}
          ],
        ], m.backend);
        m.control(1).notify();
        await tester.pumpAndSettle();
        final next = m.backend.globalKeys['k2'];
        expect(next, isNotNull);
        expect(identical(next, key), isFalse);
        expect(next!.currentContext, isNotNull);
      });
    });
  }

  group('a re-sent service', () {
    late _PingExtension extension;
    late RufletBackend backend;
    late Control registry;
    late ServiceRegistry services;

    Map<String, dynamic> ping(int id, [Object? value = 1]) =>
        {'_c': 'Ping', '_i': id, 'value': value};

    void send(List<Map<String, dynamic>> list) => registry.applyPatch([
          [0],
          [0, 0, '_services', list],
        ], backend);

    Future<Object?> invoke(int id) => backend.controlsIndex
        .get(id)!
        .invokeMethod('ping', null, const Duration(seconds: 1));

    setUp(() {
      extension = _PingExtension();
      backend = RufletBackend(
          pageUri: Uri.parse('ruflet://resend-services'),
          assetsDir: '',
          extensions: [extension],
          multiView: false);
      registry = Control.fromMap(
          {'_c': 'ServiceRegistry', '_i': 9, '_services': []}, backend);
      services = ServiceRegistry(
          control: registry, propertyName: '_services', backend: backend);
    });

    tearDown(() => services.dispose());

    test('keeps running and answers on the new object', () async {
      send([ping(10)]);
      final first = backend.controlsIndex.get(10)!;
      final service = extension.services[10]!;
      expect(await invoke(10), 'pong 1');

      // page.services << other: the list comes back with the first again.
      send([ping(10), ping(11)]);
      final second = backend.controlsIndex.get(10)!;
      expect(identical(second, first), isFalse);
      expect(extension.services[10], same(service));
      expect((service.inits, service.disposes, service.updates), (1, 0, 0));
      expect(await invoke(10), 'pong 1');
      expect(await invoke(11), 'pong 1');
      expect(service.control, same(second));
      expect(first.debugInvokeMethodListenerCount, 0);
      expect(first.isAttached, isFalse);
      expect(second.isAttached, isTrue);
    });

    test('applies the properties a re-sent copy changes, once', () async {
      send([ping(10)]);
      final service = extension.services[10]!;

      send([ping(10, 2), ping(11)]);
      expect(service.updatedValues, [2]);
      expect(await invoke(10), 'pong 2');

      // A Ruby property patch on the new object reaches the service.
      backend.controlsIndex.get(10)!.applyPatch([
        [0],
        [0, 0, 'value', 3],
      ], backend);
      expect(service.updatedValues, [2, 3]);
      expect(await invoke(10), 'pong 3');
    });

    test('is disposed once when Ruby removes it', () async {
      send([ping(10)]);
      final service = extension.services[10]!;
      send([ping(10), ping(11)]);
      send([ping(11)]);
      expect((service.inits, service.disposes), (1, 1));
      expect(service.control.debugInvokeMethodListenerCount, 0);
      expect(service.control.isAttached, isFalse);
    });
  });

  // Only these libraries register invoke listeners themselves. A State that
  // answers invokes uses InvokeMethodListenerMixin, which moves its listener
  // when Ruby re-sends the control; anything else must rebind on its own.
  test('States register invoke listeners through InvokeMethodListenerMixin',
      () {
    const allowed = {
      // Defines the listener API.
      'lib/src/models/control.dart',
      'lib/src/widgets/invoke_method_listener_mixin.dart',
      // Rebinds in didUpdateWidget.
      'lib/src/core/core_host.dart',
      // Rebinds through its `control` setter.
      'lib/src/controls/refresh_coordinator.dart',
      // The Page control (id 1) is never re-sent.
      'lib/src/controls/page.dart',
    };
    final offenders = [
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        if (file.readAsStringSync().contains('addInvokeMethodListener(') &&
            !allowed.contains(file.path) &&
            // Services rebind through ServiceBinding.rebind.
            !file.path.startsWith('lib/src/services/'))
          file.path
    ]..sort();
    expect(offenders, isEmpty);
  });
}
