// The one Dart-implemented Flutter plugin object of ruflet_native on Android
// (SPEC §4.1). It gives the features what a Kotlin plugin gets from
// ActivityAware: activity results, permission results, new intents and the
// activity lifecycle.
//
// Why one plugin object implementing exactly these five interfaces
// (FlutterPlugin, ActivityAware and the three PluginRegistry listeners):
// - FlutterEngineConnectionRegistry keys plugins by getClass() and ignores a
//   second add() of the same class. java.lang.reflect.Proxy reuses one class
//   per interface list, so two proxies with the same list (from this plugin
//   or any other jni-based plugin) cannot both register; this interface
//   list makes the class ours.
// - After a hot restart (development only) the old proxy still points at the
//   dead isolate: a blocking call into it returns null, and a null boolean
//   return throws NullPointerException in the proxy. So on registration the
//   previous proxy is looked up by class, removed from the activity
//   binding's three listener lists, and removed from the registry before
//   the new one is added.
// - Application.ActivityLifecycleCallbacks gets its own proxy (S7 finding):
//   package:jni's PortProxyBuilder defines the proxy class in the class
//   loader of the first interface of a HashMap, and when that is the
//   framework interface, the boot class loader cannot see io.flutter.*
//   ("interface ... is not visible from class loader"). Its methods are
//   void, so a lifecycle proxy left by a previous isolate after a hot
//   restart is harmless (its calls into the dead isolate return at once).
//
// Every method is called by the embedding on the main thread, where the
// root isolate runs (merged threads), so package:jni calls the Dart code
// inline (blocking implementations, SPEC §4.3 T3). Each entry ends with
// wakeEventLoop() so the futures it completes resolve at once (S6).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jni/jni.dart';

import 'bindings/shared.g.dart';
import 'jni_env.dart';

/// The activity lifecycle events of the Flutter activity.
enum ActivityLifecycleEvent { created, started, resumed, paused, stopped, destroyed }

/// Handles one activity result. [data] is valid only during the call: copy
/// what is needed. Returns whether the result was handled.
typedef ActivityResultHandler = bool Function(int resultCode, Intent? data);

/// Handles one permission result.
typedef PermissionResultHandler = void Function(
    List<String?> permissions, List<int> grantResults);

/// Handles a new intent; [intent] is valid only during the call.
typedef NewIntentHandler = bool Function(Intent intent);

/// The single plugin object registered with this engine.
class ActivityBinding {
  ActivityBinding._();

  static ActivityBinding? _instance;

  /// The binding, registered with the engine on first use. Must be called on
  /// the main thread.
  static ActivityBinding get instance =>
      _instance ??= (ActivityBinding._().._register());

  // Request codes: 16 bits (FragmentActivity rejects larger codes), in a
  // block the old plugins do not use (share_plus 0x5873, file_picker
  // (hashCode + 43) & 0xffff, permission_handler 24/209-211, geolocator
  // 109/0x5223...). Invisible to Ruby.
  static const int firstRequestCode = 0x7A00;
  static const int requestCodeCount = 0x100;
  int _nextCode = 0;

  FlutterPlugin? _proxy;
  Application$ActivityLifecycleCallbacks? _lifecycleProxy;
  ActivityPluginBinding? _binding;
  Application? _application;
  bool _lifecycleRegistered = false;
  JObject? _previousProxy;

  final Map<int, ActivityResultHandler> _resultHandlers = {};
  final Map<int, PermissionResultHandler> _permissionHandlers = {};
  final List<NewIntentHandler> _newIntentHandlers = [];
  final StreamController<ActivityLifecycleEvent> _lifecycle =
      StreamController.broadcast(sync: false);

  /// Whether an activity is attached now.
  final ValueNotifier<bool> attached = ValueNotifier(false);

  /// Lifecycle events of the engine's activity, delivered on the event queue.
  Stream<ActivityLifecycleEvent> get lifecycle => _lifecycle.stream;

  /// How many times the engine attached an activity to this binding
  /// (tests).
  @visibleForTesting
  int attachCount = 0;

  /// Whether registration found and removed a proxy left by a previous
  /// isolate (hot restart; tests).
  @visibleForTesting
  bool replacedPreviousProxy = false;

  /// How many activity results reached this object (tests).
  @visibleForTesting
  int activityResultCalls = 0;

  /// The registered proxy's Java class (tests: plugin-class uniqueness).
  @visibleForTesting
  JClass get debugProxyClass => _proxy!.jClass;

  /// Registers a new binding as a hot restart does (the previous proxy is
  /// still in the engine's registry), and makes it [instance] (tests).
  @visibleForTesting
  static ActivityBinding debugReregister() {
    final binding = ActivityBinding._().._register();
    return _instance = binding;
  }

  /// The next request code of the ruflet_native block.
  int nextRequestCode() {
    final code = firstRequestCode + _nextCode;
    _nextCode = (_nextCode + 1) % requestCodeCount;
    return lastRequestCode = code;
  }

  /// The request code handed out last (tests: cancel the started activity).
  @visibleForTesting
  int? lastRequestCode;

  /// Handles the activity result for [requestCode] once.
  void onActivityResult(int requestCode, ActivityResultHandler handler) =>
      _resultHandlers[requestCode] = handler;

  /// Handles the permission result for [requestCode] once.
  void onPermissionsResult(int requestCode, PermissionResultHandler handler) =>
      _permissionHandlers[requestCode] = handler;

  /// Adds a new-intent handler; returns a function that removes it.
  VoidCallback addNewIntentHandler(NewIntentHandler handler) {
    _newIntentHandlers.add(handler);
    return () => _newIntentHandlers.remove(handler);
  }

  /// Starts [intent] for a result with the current activity and completes
  /// with [onResult]'s value. Throws StateError without an activity.
  Future<T> startActivityForResult<T>(
      Intent intent, T Function(int resultCode, Intent? data) onResult) {
    final code = nextRequestCode();
    final completer = Completer<T>();
    onActivityResult(code, (resultCode, data) {
      try {
        completer.complete(onResult(resultCode, data));
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
      return true;
    });
    final started = withActivity((activity) {
      activity.startActivityForResult(intent, code);
      return true;
    });
    if (started == null) {
      _resultHandlers.remove(code);
      throw StateError('ruflet_native: no Android activity is attached');
    }
    return completer.future;
  }

  /// Requests [permissions] with the current activity and completes with the
  /// grant results. Throws StateError without an activity.
  Future<List<int>> requestPermissions(List<String> permissions) {
    final code = nextRequestCode();
    final completer = Completer<List<int>>();
    onPermissionsResult(code, (_, grants) => completer.complete(grants));
    final requested = withActivity((activity) {
      using((arena) {
        final array = JArray.withLength(JString.type, permissions.length)
          ..releasedBy(arena);
        for (var i = 0; i < permissions.length; i++) {
          array[i] = permissions[i].toJString()..releasedBy(arena);
        }
        activity.requestPermissions(array, code);
      });
      return true;
    });
    if (requested == null) {
      _permissionHandlers.remove(code);
      throw StateError('ruflet_native: no Android activity is attached');
    }
    return completer.future;
  }

  void _register() {
    final engine = FlutterEngine.engineForId(engineId);
    if (engine == null) {
      throw StateError('ruflet_native: FlutterEngine.engineForId($engineId) '
          'returned null');
    }
    final plugins = engine.plugins;
    engine.release();
    try {
      final implementer = JImplementer();
      FlutterPlugin.implementIn(
          implementer,
          $FlutterPlugin(
              onAttachedToEngine: _onAttachedToEngine,
              onDetachedFromEngine: _onDetachedFromEngine));
      ActivityAware.implementIn(
          implementer,
          $ActivityAware(
              onAttachedToActivity: _onAttachedToActivity,
              onDetachedFromActivityForConfigChanges: _onDetachedForConfig,
              onReattachedToActivityForConfigChanges: _onReattachedForConfig,
              onDetachedFromActivity: _onDetachedFromActivity));
      PluginRegistry$1$ActivityResultListener.implementIn(
          implementer,
          $PluginRegistry$1$ActivityResultListener(
              onActivityResult: _onActivityResult));
      PluginRegistry$1$RequestPermissionsResultListener.implementIn(
          implementer,
          $PluginRegistry$1$RequestPermissionsResultListener(
              onRequestPermissionsResult: _onRequestPermissionsResult));
      PluginRegistry$1$NewIntentListener.implementIn(implementer,
          $PluginRegistry$1$NewIntentListener(onNewIntent: _onNewIntent));
      final proxy = implementer.implement<FlutterPlugin>();
      _proxy = proxy;
      _lifecycleProxy =
          Application$ActivityLifecycleCallbacks.implement(_lifecycleCallbacks());

      // A proxy with our interface list left by a previous isolate (hot
      // restart): forget it before adding ours, or add() is ignored.
      final proxyClass = proxy.jClass;
      final previous = plugins.get(proxyClass);
      if (previous != null) {
        replacedPreviousProxy = true;
        _previousProxy = previous;
        // Calls the old proxy's onDetached* (void: jni answers null for a
        // dead isolate). Its listeners stay on the activity binding; they
        // are removed in _onAttachedToActivity, which add() calls next.
        plugins.remove(proxyClass);
      }
      proxyClass.release();
      // Calls onAttachedToEngine and, if an activity is attached,
      // onAttachedToActivity, re-entering Dart on this thread (T7).
      plugins.add(proxy);
    } finally {
      plugins.release();
    }
  }

  $Application$ActivityLifecycleCallbacks _lifecycleCallbacks() {
    void ignore(Activity? activity) => activity?.release();
    void ignore2(Activity? activity, Bundle? bundle) =>
        releaseAll([activity, bundle]);
    void Function(Activity?) on(ActivityLifecycleEvent event) =>
        (Activity? activity) => _onLifecycle(event, activity);
    return $Application$ActivityLifecycleCallbacks(
      onActivityCreated: (activity, bundle) {
        bundle?.release();
        _onLifecycle(ActivityLifecycleEvent.created, activity);
      },
      onActivityStarted: on(ActivityLifecycleEvent.started),
      onActivityResumed: on(ActivityLifecycleEvent.resumed),
      onActivityPaused: on(ActivityLifecycleEvent.paused),
      onActivityStopped: on(ActivityLifecycleEvent.stopped),
      onActivityDestroyed: on(ActivityLifecycleEvent.destroyed),
      onActivitySaveInstanceState: ignore2,
      onActivityPreCreated: ignore2,
      onActivityPostCreated: ignore2,
      onActivityPreSaveInstanceState: ignore2,
      onActivityPostSaveInstanceState: ignore2,
      onActivityPreStarted: ignore,
      onActivityPostStarted: ignore,
      onActivityPreResumed: ignore,
      onActivityPostResumed: ignore,
      onActivityPrePaused: ignore,
      onActivityPostPaused: ignore,
      onActivityPreStopped: ignore,
      onActivityPostStopped: ignore,
      onActivityPreDestroyed: ignore,
      onActivityPostDestroyed: ignore,
    );
  }

  /// Only the engine's own activity counts (the app may have others).
  void _onLifecycle(ActivityLifecycleEvent event, Activity? activity) {
    try {
      final current = _binding;
      if (activity == null || current == null) return;
      // Activity.equals is identity.
      final mine = current.getActivity().use((own) => own == activity);
      if (mine && !_lifecycle.isClosed) _lifecycle.add(event);
    } finally {
      activity?.release();
      wakeEventLoop();
    }
  }

  void _onAttachedToEngine(FlutterPlugin$FlutterPluginBinding binding) =>
      binding.release();

  void _onDetachedFromEngine(FlutterPlugin$FlutterPluginBinding binding) {
    binding.release();
    _unregisterLifecycle();
    wakeEventLoop();
  }

  void _attach(ActivityPluginBinding binding) {
    attachCount++;
    _binding = binding;
    final previous = _previousProxy;
    if (previous != null) {
      _previousProxy = null;
      binding.removeActivityResultListener(
          previous as PluginRegistry$1$ActivityResultListener);
      binding.removeRequestPermissionsResultListener(
          previous as PluginRegistry$1$RequestPermissionsResultListener);
      binding.removeOnNewIntentListener(
          previous as PluginRegistry$1$NewIntentListener);
      previous.release();
    }
    final proxy = _proxy!;
    binding.addActivityResultListener(
        proxy as PluginRegistry$1$ActivityResultListener);
    binding.addRequestPermissionsResultListener(
        proxy as PluginRegistry$1$RequestPermissionsResultListener);
    binding.addOnNewIntentListener(proxy as PluginRegistry$1$NewIntentListener);
    if (!_lifecycleRegistered) {
      _application = binding.getActivity().use((a) => a.application);
      _application?.registerActivityLifecycleCallbacks(_lifecycleProxy);
      _lifecycleRegistered = _application != null;
    }
    attached.value = true;
    wakeEventLoop();
  }

  void _detach() {
    final binding = _binding;
    _binding = null;
    attached.value = false;
    if (binding == null) return;
    final proxy = _proxy!;
    binding.removeActivityResultListener(
        proxy as PluginRegistry$1$ActivityResultListener);
    binding.removeRequestPermissionsResultListener(
        proxy as PluginRegistry$1$RequestPermissionsResultListener);
    binding.removeOnNewIntentListener(
        proxy as PluginRegistry$1$NewIntentListener);
    binding.release();
    wakeEventLoop();
  }

  void _unregisterLifecycle() {
    if (!_lifecycleRegistered) return;
    _lifecycleRegistered = false;
    _application?.unregisterActivityLifecycleCallbacks(_lifecycleProxy);
    _application?.release();
    _application = null;
  }

  void _onAttachedToActivity(ActivityPluginBinding binding) => _attach(binding);

  // Config changes (rotation) recreate the activity and its binding: the
  // listeners move to the new binding.
  void _onDetachedForConfig() => _detach();

  void _onReattachedForConfig(ActivityPluginBinding binding) => _attach(binding);

  void _onDetachedFromActivity() => _detach();

  bool _onActivityResult(int requestCode, int resultCode, Intent? data) {
    activityResultCalls++;
    try {
      final handler = _resultHandlers.remove(requestCode);
      if (handler == null) return false;
      return handler(resultCode, data);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: error, stack: stack, library: 'ruflet_native'));
      return true;
    } finally {
      data?.release();
      wakeEventLoop();
    }
  }

  bool _onRequestPermissionsResult(
      int requestCode, JArray<JString?> permissions, JIntArray grants) {
    try {
      final handler = _permissionHandlers.remove(requestCode);
      if (handler == null) return false;
      final names = [
        for (var i = 0; i < permissions.length; i++)
          permissions[i]?.toDartString(releaseOriginal: true)
      ];
      handler(names, grants.getRange(0, grants.length).toList());
      return true;
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: error, stack: stack, library: 'ruflet_native'));
      return true;
    } finally {
      permissions.release();
      grants.release();
      wakeEventLoop();
    }
  }

  bool _onNewIntent(Intent intent) {
    try {
      var handled = false;
      for (final handler in List.of(_newIntentHandlers)) {
        handled = handler(intent) || handled;
      }
      return handled;
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: error, stack: stack, library: 'ruflet_native'));
      return false;
    } finally {
      intent.release();
      wakeEventLoop();
    }
  }
}
