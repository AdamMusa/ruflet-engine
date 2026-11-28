/// Wire-level harness and fixture format for ruflet_native (SPEC §8.1).
///
/// A [WireHarness] builds a real [RufletBackend] with an in-memory channel,
/// mounts service controls through the core's ServiceBinding (the path a
/// `_services` patch takes), feeds it the `invoke_method` and `patch_control`
/// messages Ruby sends, and records every message the backend sends back, in
/// order, with its msgpack bytes.
///
/// The fixture recorder runs it with the old plugins and writes
/// `packages/ruflet/native/test/fixtures/<feature>/<platform>.json`; the
/// example app's integration tests and the host tests replay those files
/// against ruflet_native and compare.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:ruflet/ruflet.dart';
// The harness drives the real backend the way the transport does, which
// needs the protocol and the service binding.
// ignore: implementation_imports
import 'package:ruflet/src/protocol/message.dart';
// ignore: implementation_imports
import 'package:ruflet/src/services/service_binding.dart';
// ignore: implementation_imports
import 'package:ruflet/src/transport/ruflet_msgpack_encoder.dart';

/// One step of a case: what Ruby sends.
sealed class WireStep {
  const WireStep();

  Map<String, Object?> toJson();

  static WireStep fromJson(Map<String, Object?> json) => switch (json['step']) {
        'invoke' => Invoke(json['method'] as String,
            args: json['args'], timeout: json['timeout'] as int? ?? 10),
        'patch' => Patch(
            (json['props'] as Map).cast<String, Object?>()),
        'wait' => Wait(Duration(milliseconds: json['ms'] as int)),
        _ => throw FormatException('unknown step $json'),
      };
}

/// `page.invoke` / `#invoke_sync`: an `invoke_method` message.
class Invoke extends WireStep {
  const Invoke(this.method, {this.args, this.timeout = 10});
  final String method;
  final Object? args;
  final int timeout;

  @override
  Map<String, Object?> toJson() =>
      {'step': 'invoke', 'method': method, 'args': args, 'timeout': timeout};
}

/// A property update of the case's control (for example `on_change: true`),
/// applied as a `patch_control` message would apply it.
class Patch extends WireStep {
  const Patch(this.props);
  final Map<String, Object?> props;

  @override
  Map<String, Object?> toJson() => {'step': 'patch', 'props': props};
}

/// Lets events arrive for [duration].
class Wait extends WireStep {
  const Wait(this.duration);
  final Duration duration;

  @override
  Map<String, Object?> toJson() =>
      {'step': 'wait', 'ms': duration.inMilliseconds};
}

/// A scripted case: one service control and the messages Ruby sends to it.
class CaseSpec {
  const CaseSpec(
      {required this.name,
      required this.control,
      required this.steps,
      this.volatile = false});

  final String name;

  /// The control as Ruby creates it (`{'_c': 'Flashlight', '_i': 101, ...}`).
  final Map<String, Object?> control;
  final List<WireStep> steps;

  /// Device-dependent results: compared by type and shape only.
  final bool volatile;

  int get controlId => control['_i'] as int;

  Map<String, Object?> toJson() => {
        'name': name,
        'control': control,
        'steps': [for (final s in steps) s.toJson()],
        'volatile': volatile,
      };

  static CaseSpec fromJson(Map<String, Object?> json) => CaseSpec(
        name: json['name'] as String,
        control: (json['control'] as Map).cast<String, Object?>(),
        steps: [
          for (final s in json['steps'] as List)
            WireStep.fromJson((s as Map).cast<String, Object?>())
        ],
        volatile: json['volatile'] as bool? ?? false,
      );
}

/// A message the backend sent, as recorded.
class WireMessage {
  WireMessage(this.action, this.payload, this.msgpackBytes);

  WireMessage.fromJson(Map<String, Object?> json)
      : action = json['action'] as String,
        payload = json['payload'],
        msgpackBytes = base64Decode(json['msgpack'] as String),
        _types = (json['types'] as Map?)?.cast<String, Object?>();

  /// `invoke_method` (a reply) or `control_event`.
  final String action;

  /// The payload as JSON (see [toJsonValue]).
  final Object? payload;

  /// The exact bytes the transport sends.
  final Uint8List msgpackBytes;

  Map<String, Object?>? _types;

  /// The Dart types inside the payload (DateTime vs int matters on the wire).
  Map<String, Object?> get types => _types ?? const {};

  Map<String, Object?> toJson() => {
        'action': action,
        'payload': payload,
        'msgpack': base64Encode(msgpackBytes),
        'types': types,
      };
}

String _actionName(MessageAction action) => switch (action) {
      MessageAction.invokeControlMethod => 'invoke_method',
      MessageAction.controlEvent => 'control_event',
      MessageAction.updateControl => 'update_control',
      MessageAction.patchControl => 'patch_control',
      MessageAction.registerClient => 'register_client',
      MessageAction.sessionCrashed => 'session_crashed',
    };

/// A JSON form of a wire value that keeps what JSON cannot: DateTime,
/// Duration and bytes are tagged.
Object? toJsonValue(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is DateTime) return {r'$datetime': value.toUtc().toIso8601String()};
  if (value is Duration) return {r'$duration_us': value.inMicroseconds};
  if (value is Uint8List) return {r'$bytes': base64Encode(value)};
  if (value is List) return [for (final v in value) toJsonValue(v)];
  if (value is Map) {
    return {for (final e in value.entries) '${e.key}': toJsonValue(e.value)};
  }
  return {r'$other': value.runtimeType.toString(), 'value': '$value'};
}

/// The Dart type names inside [value], by path (`result`, `data.timestamp`).
Map<String, Object?> typesOf(Object? value, [String path = '']) {
  final out = <String, Object?>{};
  void visit(Object? v, String p) {
    if (v is Map) {
      for (final e in v.entries) {
        visit(e.value, p.isEmpty ? '${e.key}' : '$p.${e.key}');
      }
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        visit(v[i], '$p[$i]');
      }
    } else {
      out[p] = v == null ? 'Null' : _typeName(v);
    }
  }

  visit(value, path);
  return out;
}

String _typeName(Object v) => switch (v) {
      bool() => 'bool',
      int() => 'int',
      double() => 'double',
      String() => 'String',
      DateTime() => 'DateTime',
      Duration() => 'Duration',
      Uint8List() => 'Uint8List',
      _ => v.runtimeType.toString(),
    };

class _RecordingChannel implements RufletBackendChannel {
  _RecordingChannel(this.onMessage);

  final RufletBackendChannelOnMessageCallback onMessage;
  final List<Message> sent = [];
  final StreamController<Message> _sent = StreamController.broadcast(sync: true);

  @override
  Future connect() async {}

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 500;

  @override
  void send(Message message) {
    sent.add(message);
    _sent.add(message);
  }

  @override
  void disconnect() {}
}

/// A real backend with an in-memory transport.
class WireHarness {
  WireHarness._(this.backend, this._channel);

  /// Connects a backend with [extensions] (the core is appended last, as in
  /// every app).
  static Future<WireHarness> start(List<RufletExtension> extensions) async {
    late _RecordingChannel channel;
    final backend = RufletBackend(
        pageUri: Uri.parse('ruflet://ruflet-native-wire'),
        assetsDir: '',
        extensions: extensions,
        multiView: false,
        channelBuilder: (
                {required address,
                required args,
                required forcePyodide,
                required onDisconnect,
                required onMessage}) =>
            channel = _RecordingChannel(onMessage));
    for (final extension in backend.extensions) {
      extension.ensureInitialized();
    }
    await backend.connect();
    // As after Ruby's register_client answer: the backend sends directly.
    backend.isLoading = false;
    channel.sent.clear();
    return WireHarness._(backend, channel);
  }

  final RufletBackend backend;
  final _RecordingChannel _channel;
  final Map<int, ServiceBinding> _bindings = {};
  var _callId = 0;

  /// Mounts [control] as a service, as a `_services` patch does, and returns
  /// what the mount produced: null, or the error text when no extension
  /// serves the type (`Exception: Unknown service: <Type>`).
  String? mount(Map<String, Object?> control) {
    final c = Control.fromMap(control, backend);
    try {
      _bindings[c.id] = ServiceBinding(control: c, backend: backend);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Unmounts every service (dispose), as removing them from `_services`.
  void unmountAll() {
    for (final binding in _bindings.values) {
      binding.dispose();
    }
    _bindings.clear();
  }

  /// Runs [spec] and returns every message the backend sent meanwhile.
  Future<List<WireMessage>> run(CaseSpec spec,
      {Duration replyTimeout = const Duration(seconds: 15),
      Duration settle = const Duration(milliseconds: 100)}) async {
    _channel.sent.clear();
    // Call ids restart per case, so a replay sends the same bytes.
    _callId = 0;
    final mountError = mount(spec.control);
    if (mountError != null) {
      return [
        WireMessage('mount_error', mountError, Uint8List(0)),
      ];
    }
    for (final step in spec.steps) {
      switch (step) {
        case Invoke():
          final callId = 'call_${++_callId}';
          final reply = _channel._sent.stream.firstWhere((m) =>
              m.action == MessageAction.invokeControlMethod &&
              (m.payload as Map)['call_id'] == callId);
          _channel.onMessage(Message(
              action: MessageAction.invokeControlMethod,
              payload: {
                'control_id': spec.controlId,
                'call_id': callId,
                'name': step.method,
                'args': step.args,
                'timeout': step.timeout,
              }));
          await reply.timeout(replyTimeout);
        case Patch():
          backend.controlsIndex
              .get(spec.controlId)!
              .update(Map<String, dynamic>.of(step.props), shouldNotify: true);
        case Wait():
          await Future<void>.delayed(step.duration);
      }
    }
    await Future<void>.delayed(settle);
    unmountAll();
    return [
      for (final m in _channel.sent)
        if (m.action == MessageAction.invokeControlMethod ||
            m.action == MessageAction.controlEvent)
          _record(m)
    ];
  }

  WireMessage _record(Message m) {
    final bytes = Uint8List.fromList(
        msgpack.serialize(m.toList(), extEncoder: RufletMsgpackEncoder()));
    final payload = m.payload as Map;
    final types = typesOf(m.action == MessageAction.invokeControlMethod
        ? {'result': payload['result'], 'error': payload['error']}
        : {'data': payload['data']});
    return WireMessage(_actionName(m.action), toJsonValue(payload), bytes)
      .._types = types;
  }

  void dispose() {
    unmountAll();
    backend.dispose();
  }
}

/// One recorded case.
class FixtureCase {
  FixtureCase(this.spec, this.out);

  FixtureCase.fromJson(Map<String, Object?> json)
      : spec = CaseSpec.fromJson(json),
        out = [
          for (final m in json['out'] as List)
            WireMessage.fromJson((m as Map).cast<String, Object?>())
        ];

  final CaseSpec spec;
  final List<WireMessage> out;

  Map<String, Object?> toJson() =>
      {...spec.toJson(), 'out': [for (final m in out) m.toJson()]};
}

/// `test/fixtures/<feature>/<platform>.json`.
class Fixture {
  Fixture(
      {required this.feature,
      required this.platform,
      required this.deviceClass,
      required this.device,
      required this.recordedWith,
      required this.cases});

  factory Fixture.fromJson(Map<String, Object?> json) => Fixture(
        feature: json['feature'] as String,
        platform: json['platform'] as String,
        deviceClass: json['device_class'] as String,
        device: json['device'] as String,
        recordedWith: (json['recorded_with'] as Map).cast<String, Object?>(),
        cases: [
          for (final c in json['cases'] as List)
            FixtureCase.fromJson((c as Map).cast<String, Object?>())
        ],
      );

  final String feature;

  /// `android` or `ios`.
  final String platform;

  /// `android-emulator`, `ios-simulator`, `android-device`, `ios-device`:
  /// replay compares only on the same class of device.
  final String deviceClass;

  /// Free text: model and OS version.
  final String device;

  /// The packages (old plugin versions), Flutter version and commits.
  final Map<String, Object?> recordedWith;
  final List<FixtureCase> cases;

  Map<String, Object?> toJson() => {
        'format': 1,
        'feature': feature,
        'platform': platform,
        'device_class': deviceClass,
        'device': device,
        'recorded_with': recordedWith,
        'cases': [for (final c in cases) c.toJson()],
      };

  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

/// The differences between a recorded case and a replay; empty when equal.
///
/// Non-volatile messages must match byte for byte. Volatile cases, and every
/// case with [shapeOnly] (a replay on another device than the recording),
/// compare the message actions, their order and the Dart types only.
List<String> compareCase(FixtureCase recorded, List<WireMessage> actual,
    {bool shapeOnly = false}) {
  final problems = <String>[];
  final name = recorded.spec.name;
  if (recorded.out.length != actual.length) {
    problems.add('$name: ${recorded.out.length} messages recorded, '
        '${actual.length} replayed:\n  recorded ${[
      for (final m in recorded.out) m.payload
    ]}\n  replayed ${[for (final m in actual) m.payload]}');
    return problems;
  }
  for (var i = 0; i < actual.length; i++) {
    final r = recorded.out[i];
    final a = actual[i];
    if (r.action != a.action) {
      problems.add('$name[$i]: action ${r.action} != ${a.action}');
      continue;
    }
    if (recorded.spec.volatile || shapeOnly) {
      if (!mapEquals(r.types, a.types)) {
        problems.add('$name[$i]: types ${r.types} != ${a.types}');
      }
    } else if (!listEquals(r.msgpackBytes, a.msgpackBytes)) {
      problems.add('$name[$i]: bytes differ\n  recorded ${r.payload}\n  '
          'replayed ${a.payload}');
    }
  }
  return problems;
}

/// The case's replies and errors as text, for test failure messages.
String describe(List<WireMessage> messages) =>
    messages.map((m) => '${m.action} ${jsonEncode(m.payload)}').join('\n');
