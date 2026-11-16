// ruflet-coverage: Audio
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart' show AudioLogger, AudioLogLevel;
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_audio/ruflet_audio.dart';
import 'package:ruflet_audio/src/audio.dart';

const _timeout = Duration(seconds: 2);

/// Dart fake of the audioplayers platform, so no platform channel is used.
/// It records every call the player makes, answers like a native player
/// (prepared after a source, seekComplete after a seek) and lets a test push
/// events.
class _FakePlayers extends AudioplayersPlatformInterface {
  final _events = StreamController<AudioEvent>.broadcast();
  final calls = <List<Object?>>[];
  final loadedBytes = <Uint8List>[];
  PlatformException? loadError;
  int positionMs = 0;
  int? durationMs = 5000;

  void emit(AudioEvent event) => _events.add(event);

  /// The recorded calls to [method], without the method name.
  List<List<Object?>> callsTo(String method) => [
        for (final call in calls)
          if (call.first == method) call.sublist(1)
      ];

  void _prepared() {
    // Native players report load failures on the player's event channel.
    if (loadError != null) {
      _events.addError(loadError!);
    } else {
      _events.add(const AudioEvent(
          eventType: AudioEventType.prepared, isPrepared: true));
    }
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) => _events.stream;

  @override
  Future<void> create(String playerId) async {}

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes,
      {String? mimeType}) async {
    calls.add(['setSourceBytes', bytes]);
    loadedBytes.add(bytes);
    _prepared();
  }

  @override
  Future<void> setSourceUrl(String playerId, String url,
      {bool? isLocal, String? mimeType}) async {
    calls.add(['setSourceUrl', url, isLocal]);
    _prepared();
  }

  @override
  Future<void> resume(String playerId) async => calls.add(['resume']);

  @override
  Future<void> pause(String playerId) async => calls.add(['pause']);

  @override
  Future<void> stop(String playerId) async => calls.add(['stop']);

  @override
  Future<void> release(String playerId) async => calls.add(['release']);

  @override
  Future<void> dispose(String playerId) async => calls.add(['dispose']);

  @override
  Future<void> seek(String playerId, Duration position) async {
    calls.add(['seek', position]);
    positionMs = position.inMilliseconds;
    _events.add(const AudioEvent(eventType: AudioEventType.seekComplete));
  }

  @override
  Future<void> setVolume(String playerId, double volume) async =>
      calls.add(['setVolume', volume]);

  @override
  Future<void> setBalance(String playerId, double balance) async =>
      calls.add(['setBalance', balance]);

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async =>
      calls.add(['setPlaybackRate', playbackRate]);

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async =>
      calls.add(['setReleaseMode', releaseMode]);

  @override
  Future<int?> getCurrentPosition(String playerId) async => positionMs;

  @override
  Future<int?> getDuration(String playerId) async => durationMs;

  // setAudioContext, setPlayerMode, emitLog, emitError all succeed.
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeGlobal implements GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Records events exactly as the real backend sends them: only when Ruby
/// subscribed with `on_<name>: true`.
class _Backend extends RufletBackend {
  final events = <(String, dynamic)>[];

  _Backend({super.assetsDir = ''})
      : super(
            pageUri: Uri.parse('ruflet://audio-test'),
            extensions: [Extension()],
            multiView: false);

  @override
  void triggerControlEvent(Control control, String eventName, [dynamic data]) {
    if (control.get("on_$eventName") == true) {
      events.add((eventName, data));
    }
  }

  /// The names of the events sent, in order.
  List<String> get names => [for (final e in events) e.$1];

  /// The data of every [name] event, in order.
  List<dynamic> dataOf(String name) => [
        for (final e in events)
          if (e.$1 == name) e.$2
      ];
}

/// Every Audio event Ruby can subscribe to.
const _allEvents = {
  'on_loaded': true,
  'on_error': true,
  'on_state_change': true,
  'on_duration_change': true,
  'on_position_change': true,
  'on_seek_complete': true,
};

/// An Audio service mounted as ServiceBinding mounts it: created by the
/// extension, initialized, attached, and updated when its control changes.
class _Mounted {
  _Mounted(this.backend, this.control, this.service);
  final _Backend backend;
  final Control control;
  final AudioService service;

  /// Invokes [name] the way the backend does and lets the player's futures
  /// settle; returns what Ruby would receive: the value or the error.
  Future<({Object? value, Object? error})> outcome(
      WidgetTester tester, String name,
      [Object? args]) async {
    Object? value;
    Object? error;
    var done = false;
    unawaited(control.invokeMethod(name, args, _timeout).then((v) {
      value = v;
      done = true;
    }, onError: (Object e) {
      error = e;
      done = true;
    }));
    for (var i = 0; i < 20 && !done; i++) {
      await tester.pump();
    }
    expect(done, isTrue, reason: 'Audio.$name did not settle');
    return (value: value, error: error);
  }

  /// The value of a successful invoke.
  Future<Object?> invoke(WidgetTester tester, String name,
      [Object? args]) async {
    final result = await outcome(tester, name, args);
    expect(result.error, isNull, reason: 'Audio.$name failed');
    return result.value;
  }

  /// Applies a Ruby property update.
  Future<void> update(WidgetTester tester, Map<String, dynamic> props) async {
    control.update(props, shouldNotify: true);
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    control.removeListener(service.update);
    control.detach();
    service.dispose();
    await tester.pump();
  }
}

void main() {
  late _FakePlayers players;

  setUp(() {
    // The player logs the load failures the tests provoke.
    AudioLogger.logLevel = AudioLogLevel.none;
    players = _FakePlayers();
    AudioplayersPlatformInterface.instance = players;
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobal();
  });

  Future<_Mounted> mount(WidgetTester tester, Map<String, dynamic> props,
      {String assetsDir = ''}) async {
    final backend = _Backend(assetsDir: assetsDir);
    final control =
        Control.fromMap({'_c': 'Audio', '_i': 1, ...props}, backend);
    final service = Extension().createService(control)! as AudioService;
    service.init();
    control.attach();
    control.addListener(service.update);
    await tester.pump();
    await tester.pump();
    return _Mounted(backend, control, service);
  }

  Future<_Backend> run(WidgetTester tester, Map<String, dynamic> props) async {
    final mounted =
        await mount(tester, {'on_loaded': true, 'on_error': true, ...props});
    await mounted.unmount(tester);
    return mounted.backend;
  }

  test('the extension creates the service for its wire type only', () {
    final backend = _Backend();
    Control control(String type) =>
        Control(id: 1, type: type, properties: {}, backend: backend);

    expect(Extension().createService(control('Audio')), isA<AudioService>());
    expect(Extension().createService(control('Video')), isNull);
    expect(Extension().createWidget(null, control('Audio')), isNull);
  });

  testWidgets('loads Ruby src_base64 as bytes', (tester) async {
    final backend = await run(tester, {'src_base64': 'AAEC'});
    expect(players.loadedBytes, [
      [0, 1, 2]
    ]);
    expect(backend.events, [('loaded', null)]);
  });

  testWidgets('prefers src over src_base64', (tester) async {
    await run(tester, {
      'src': base64Encode([9]),
      'src_base64': 'AAEC'
    });
    expect(players.loadedBytes, [
      [9]
    ]);
  });

  testWidgets('fires error instead of throwing when there is no source',
      (tester) async {
    final backend = await run(tester, {});
    expect(players.loadedBytes, isEmpty);
    expect(backend.events,
        [('error', 'Audio must have "src" or "src_base64" specified.')]);
  });

  testWidgets('fires one error event when the player fails to load',
      (tester) async {
    players.loadError =
        PlatformException(code: 'AudioError', message: 'cannot decode');
    final backend = await run(tester, {
      'src_base64': base64Encode([1, 2, 3])
    });
    expect(players.loadedBytes, [
      [1, 2, 3]
    ]);
    expect(backend.events, hasLength(1));
    expect(backend.events.single.$1, 'error');
    expect(backend.events.single.$2, contains('cannot decode'));
  });

  testWidgets('a src_base64 that is not a source is an error event, not a load',
      (tester) async {
    final backend = await run(tester, {'src_base64': 42});
    expect(players.callsTo('setSourceBytes'), isEmpty);
    expect(players.callsTo('setSourceUrl'), isEmpty);
    expect(backend.events, [
      (
        'error',
        'Audio src_base64 decode error: int is not a supported source type.'
      )
    ]);
  });

  testWidgets('a URL src loads remotely, a file src loads from the device',
      (tester) async {
    final url = await mount(tester, {
      'src': 'https://example.com/song.mp3',
      'on_loaded': true,
    });
    expect(players.callsTo('setSourceUrl'), [
      ['https://example.com/song.mp3', false]
    ]);
    expect(url.backend.names, ['loaded']);
    await url.unmount(tester);

    players.calls.clear();
    final dir = io.Directory.systemTemp.createTempSync('ruflet_audio_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = io.File('${dir.path}/beep.wav')..writeAsBytesSync([0]);
    final local = await mount(tester, {'src': file.path});
    expect(players.callsTo('setSourceUrl'), [
      [file.path, true]
    ]);
    await local.unmount(tester);

    // A relative src resolves inside the app's assets directory.
    players.calls.clear();
    final asset = await mount(tester, {'src': 'sounds/beep.wav'},
        assetsDir: dir.path);
    expect(players.callsTo('setSourceUrl'), [
      ['${dir.path}/sounds/beep.wav', true]
    ]);
    await asset.unmount(tester);
  });

  testWidgets('volume, balance, playback_rate and release_mode reach the player',
      (tester) async {
    final audio = await mount(tester, {
      'src_base64': 'AAEC',
      'volume': 0.25,
      'balance': -0.5,
      'playback_rate': 1.5,
      'release_mode': 'loop',
    });

    expect(players.callsTo('setVolume'), [
      [0.25]
    ]);
    expect(players.callsTo('setBalance'), [
      [-0.5]
    ]);
    expect(players.callsTo('setPlaybackRate'), [
      [1.5]
    ]);
    expect(players.callsTo('setReleaseMode'), [
      [ReleaseMode.loop]
    ]);
    // Without autoplay nothing plays.
    expect(players.callsTo('resume'), isEmpty);

    // Ruby updates apply only what changed; out-of-range values are ignored.
    players.calls.clear();
    await audio.update(tester, {
      'volume': 0.75,
      'balance': 3,
      'release_mode': 'stop',
    });
    expect(players.calls, [
      ['setReleaseMode', ReleaseMode.stop],
      ['setVolume', 0.75],
    ]);

    players.calls.clear();
    await audio.update(tester, {'volume': 1.5, 'playback_rate': 1.5});
    expect(players.calls, isEmpty);
    await audio.unmount(tester);
  });

  testWidgets('defaults: full volume, centred, normal rate, no release mode',
      (tester) async {
    final audio = await mount(tester, {'src_base64': 'AAEC'});
    expect(players.callsTo('setVolume'), [
      [1.0]
    ]);
    expect(players.callsTo('setBalance'), [
      [0.0]
    ]);
    expect(players.callsTo('setPlaybackRate'), [
      [1.0]
    ]);
    expect(players.callsTo('setReleaseMode'), isEmpty);
    await audio.unmount(tester);
  });

  testWidgets('autoplay plays once when the source loads, and again on a new src',
      (tester) async {
    final audio = await mount(tester, {
      'src_base64': 'AAEC',
      'autoplay': true,
      'on_state_change': true,
    });
    expect(players.callsTo('resume'), hasLength(1));
    expect(players.calls.last, ['resume']);
    expect(audio.backend.dataOf('state_change'), [
      {'state': 'playing'}
    ]);

    // An unrelated update does not reload or replay.
    await audio.update(tester, {'volume': 0.5});
    expect(players.callsTo('setSourceBytes'), hasLength(1));
    expect(players.callsTo('resume'), hasLength(1));

    await audio.update(tester, {'src_base64': 'AQID'});
    expect(players.loadedBytes.last, [1, 2, 3]);
    expect(players.callsTo('resume'), hasLength(2));
    await audio.unmount(tester);
  });

  testWidgets('play seeks to Ruby\'s position, then plays', (tester) async {
    final audio = await mount(tester, {'src_base64': 'AAEC'});

    players.calls.clear();
    // Ruby's play(position: 0) default.
    expect(await audio.invoke(tester, 'play', {'position': 0}), isNull);
    expect(players.calls, [
      ['seek', Duration.zero],
      ['resume'],
    ]);

    players.calls.clear();
    await audio.invoke(tester, 'play', {'position': 1500});
    expect(players.calls, [
      ['seek', const Duration(milliseconds: 1500)],
      ['resume'],
    ]);

    // Without a position it plays from where it is.
    players.calls.clear();
    await audio.invoke(tester, 'play', null);
    expect(players.calls, [
      ['resume'],
    ]);
    await audio.unmount(tester);
  });

  testWidgets('pause, resume, release and seek reach the player',
      (tester) async {
    final audio = await mount(tester, {'src_base64': 'AAEC'});
    players.calls.clear();

    expect(await audio.invoke(tester, 'resume'), isNull);
    expect(await audio.invoke(tester, 'pause'), isNull);
    // Ruby's seek(position_milliseconds).
    expect(await audio.invoke(tester, 'seek', {'position': 2500}), isNull);
    expect(await audio.invoke(tester, 'release'), isNull);
    expect(players.calls, [
      ['resume'],
      ['pause'],
      ['seek', const Duration(milliseconds: 2500)],
      ['stop'],
      ['release'],
    ]);

    // A seek without a position does nothing.
    players.calls.clear();
    await audio.invoke(tester, 'seek', null);
    expect(players.calls, isEmpty);
    await audio.unmount(tester);
  });

  testWidgets('get_duration and get_current_position return Durations',
      (tester) async {
    final audio = await mount(tester, {'src_base64': 'AAEC'});
    players.durationMs = 184000;
    players.positionMs = 61500;

    expect(await audio.invoke(tester, 'get_duration'),
        const Duration(minutes: 3, seconds: 4));
    expect(await audio.invoke(tester, 'get_current_position'),
        const Duration(minutes: 1, seconds: 1, milliseconds: 500));

    // Nothing loaded yet: the platform has no duration.
    players.durationMs = null;
    expect(await audio.invoke(tester, 'get_duration'), isNull);
    await audio.unmount(tester);
  });

  testWidgets('an unknown method is an error; a disposed service answers none',
      (tester) async {
    final audio = await mount(tester, {'src_base64': 'AAEC'});
    expect((await audio.outcome(tester, 'stop')).error.toString(),
        'Exception: Unknown Audio method: stop');

    audio.service.dispose();
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    // Disposing the service releases the native player.
    expect(players.calls.sublist(players.calls.length - 2), [
      ['stop'],
      ['release'],
    ]);
    expect(
        (await audio.outcome(tester, 'play', {'position': 0})).error,
        isA<UnsupportedError>().having(
            (e) => e.message, 'message', contains('Audio(1).play')));
    audio.control.detach();
  });

  testWidgets('state, duration, position and seek events reach Ruby',
      (tester) async {
    players.positionMs = 1400;
    final audio = await mount(tester, {'src_base64': 'AAEC', ..._allEvents});
    // Loading reports the position once, rounded to the second.
    expect(audio.backend.names, ['loaded', 'position_change']);
    expect(audio.backend.dataOf('position_change'), [
      {'position': 1000}
    ]);

    players.emit(const AudioEvent(
        eventType: AudioEventType.duration,
        duration: Duration(seconds: 42)));
    await tester.pump();
    expect(audio.backend.dataOf('duration_change'), [
      {'duration': const Duration(seconds: 42)}
    ]);

    audio.backend.events.clear();
    await audio.invoke(tester, 'seek', {'position': 2600});
    expect(audio.backend.names, ['seek_complete', 'position_change']);
    expect(audio.backend.dataOf('position_change'), [
      {'position': 3000}
    ]);

    // Same second again: no new position event.
    audio.backend.events.clear();
    players.positionMs = 3100;
    await audio.invoke(tester, 'seek', {'position': 3100});
    expect(audio.backend.events, [('seek_complete', null)]);

    audio.backend.events.clear();
    await audio.invoke(tester, 'pause');
    await audio.invoke(tester, 'resume');
    await audio.invoke(tester, 'pause');
    await audio.invoke(tester, 'release');
    expect(audio.backend.dataOf('state_change'), [
      {'state': 'paused'},
      {'state': 'playing'},
      {'state': 'paused'},
      {'state': 'stopped'},
    ]);

    // The player finishing is a completed state.
    audio.backend.events.clear();
    players.emit(const AudioEvent(eventType: AudioEventType.complete));
    await tester.pump();
    expect(audio.backend.dataOf('state_change'), [
      {'state': 'completed'}
    ]);
    await audio.unmount(tester);
  });

  testWidgets('events Ruby did not subscribe to are not sent', (tester) async {
    final audio = await mount(tester, {'src_base64': 'AAEC', 'autoplay': true});
    players.emit(const AudioEvent(
        eventType: AudioEventType.duration, duration: Duration(seconds: 1)));
    await audio.invoke(tester, 'seek', {'position': 5000});
    await audio.invoke(tester, 'pause');
    expect(audio.backend.events, isEmpty);
    await audio.unmount(tester);
  });

  testWidgets('a duration stream error is reported once as on_error',
      (tester) async {
    final audio =
        await mount(tester, {'src_base64': 'AAEC', 'on_error': true});
    final failure = PlatformException(code: 'AudioError', message: 'lost');
    players._events.addError(failure);
    await tester.pump();
    expect(audio.backend.names, ['error']);
    expect(audio.backend.events.single.$2, contains('lost'));
    await audio.unmount(tester);
  });
}
