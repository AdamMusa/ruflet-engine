// jnigen config for the shared Android bindings of ruflet_native
// (lib/src/ffi/android/bindings/shared.g.dart).
//
// The classpath comes from the generated example app (addGradleDeps), as in
// path_provider_android. Build it once first:
//   tool/ruflet_native/prepare_example.sh example
//   (cd tool/ruflet_native/example && flutter build apk --debug)
//   (cd tool/ruflet_native/bindings && dart run generate.dart)
//
// Interfaces that Dart implements are generated whole. The large framework
// classes keep only the members in [keep]: features that need more generate
// their own bindings in their own folder (duplicate bindings are harmless),
// and lib/src/ffi stays frozen after PR 1.
import 'package:jnigen/jnigen.dart';
// ignore: implementation_imports
import 'package:jnigen/src/elements/j_elements.dart' as j;

/// Members kept per class; a class missing here is generated whole.
const keep = <String, Set<String>>{
  'android.content.Context': {
    'getApplicationContext', 'getMainLooper', 'getMainExecutor',
    'getPackageName', 'getPackageManager', 'getSystemService',
    'getContentResolver', 'getCacheDir', 'getFilesDir', 'startActivity',
    'checkSelfPermission',
    // Constants used by the shared layer and the planned features.
    'MODE_PRIVATE', 'CAMERA_SERVICE', 'SENSOR_SERVICE', 'CONNECTIVITY_SERVICE',
    'LOCATION_SERVICE', 'CLIPBOARD_SERVICE', 'BATTERY_SERVICE',
    'POWER_SERVICE', 'AUDIO_SERVICE', 'DISPLAY_SERVICE', 'KEYGUARD_SERVICE',
  },
  'android.app.Activity': {
    'getApplication', 'getWindow', 'getIntent', 'startActivityForResult',
    'requestPermissions', 'shouldShowRequestPermissionRationale', 'finishActivity',
    'isFinishing', 'isDestroyed', 'runOnUiThread',
  },
  'android.app.Application': {
    'registerActivityLifecycleCallbacks',
    'unregisterActivityLifecycleCallbacks',
  },
  'android.content.Intent': {
    '<init>', 'setAction', 'getAction', 'setData', 'getData', 'setType', 'getType',
    'addFlags', 'setFlags', 'putExtra', 'getStringExtra', 'getIntExtra',
    'getBooleanExtra', 'getExtras', 'setPackage', 'resolveActivity',
    'createChooser', 'addCategory',
    'ACTION_VIEW', 'ACTION_SEND', 'ACTION_SEND_MULTIPLE', 'ACTION_GET_CONTENT',
    'ACTION_OPEN_DOCUMENT', 'ACTION_BATTERY_CHANGED', 'CATEGORY_OPENABLE',
    'EXTRA_TEXT', 'EXTRA_SUBJECT', 'EXTRA_STREAM', 'EXTRA_TITLE',
    'FLAG_ACTIVITY_NEW_TASK', 'FLAG_GRANT_READ_URI_PERMISSION',
  },
  'android.os.Bundle': {
    '<init>', 'getString', 'getInt', 'getBoolean', 'putString', 'putInt',
    'putBoolean', 'containsKey', 'keySet',
  },
  'android.net.Uri': {'parse', 'toString', 'getScheme', 'getPath', 'fromFile'},
  'android.content.pm.PackageManager': {
    'hasSystemFeature', 'getPackageInfo', 'PERMISSION_GRANTED',
    'PERMISSION_DENIED',
  },
  'android.provider.Settings': {
    'ACTION_APPLICATION_DETAILS_SETTINGS', 'ACTION_LOCATION_SOURCE_SETTINGS',
    'ACTION_MANAGE_WRITE_SETTINGS', 'canDrawOverlays',
  },
  'android.provider.Settings\$System': {
    'getInt', 'getString', 'canWrite', 'SCREEN_BRIGHTNESS', 'SCREEN_BRIGHTNESS_MODE',
  },
  'android.os.Build\$VERSION': {'SDK_INT', 'RELEASE', 'CODENAME'},
  'io.flutter.embedding.engine.plugins.FlutterPlugin\$FlutterPluginBinding': {
    'getApplicationContext', 'getFlutterEngine',
  },
  // The deprecated v1 registry interface: only its nested listener
  // interfaces are needed.
  'io.flutter.plugin.common.PluginRegistry': <String>{},
  'android.os.Handler': {'<init>', 'post', 'postDelayed', 'removeCallbacks', 'getLooper'},
  'android.os.Looper': {'getMainLooper', 'myLooper', 'isCurrentThread', 'getThread'},
  'androidx.core.content.ContextCompat': {'getMainExecutor', 'checkSelfPermission'},
  'androidx.core.content.FileProvider': {'getUriForFile'},
  'io.flutter.embedding.engine.FlutterEngine': {
    'engineForId', 'getPlugins', 'getEngineId', 'getRenderer',
  },
};

/// Nested classes generated for each top-level class (jnigen pulls every
/// nested class of a listed class); a top-level class missing here keeps
/// none of its nested classes.
const nested = <String, Set<String>>{
  'android.app.Application': {'ActivityLifecycleCallbacks'},
  'android.os.Build': {'VERSION'},
  'android.provider.Settings': {'System'},
  'io.flutter.embedding.engine.plugins.FlutterPlugin': {'FlutterPluginBinding'},
  'io.flutter.plugin.common.PluginRegistry': {
    'ActivityResultListener', 'RequestPermissionsResultListener',
    'NewIntentListener',
  },
};

class _Keep extends j.Visitor {
  Set<String>? _members;

  @override
  void visitClass(j.ClassDecl c) {
    final name = c.binaryName.replaceAll('/', '.');
    final dollar = name.indexOf(r'$');
    if (dollar > 0) {
      final outer = name.substring(0, dollar);
      final inner = name.substring(dollar + 1);
      if (!(nested[outer]?.contains(inner) ?? false)) {
        c.isExcluded = true;
        _members = const {};
        return;
      }
    }
    _members = keep[name];
  }

  @override
  void visitMethod(j.Method method) {
    final members = _members;
    if (members == null) return;
    final name = method.isConstructor ? '<init>' : method.originalName;
    if (!members.contains(name)) method.isExcluded = true;
  }

  @override
  void visitField(j.Field field) {
    final members = _members;
    if (members == null) return;
    if (!members.contains(field.originalName)) field.isExcluded = true;
  }
}

Config sharedConfig(Uri packageRoot, Uri exampleRoot) => Config(
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          path: packageRoot
              .resolve('lib/src/ffi/android/bindings/shared.g.dart'),
          structure: OutputStructure.singleFile,
        ),
      ),
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        androidExample: exampleRoot.toFilePath(),
      ),
      visitors: [_Keep()],
      classes: [
        'android.content.Context',
        'android.app.Activity',
        'android.app.Application',
        'android.content.Intent',
        'android.os.Bundle',
        'android.net.Uri',
        'android.os.Build',
        'android.provider.Settings',
        'android.content.pm.PackageManager',
        'android.os.Handler',
        'android.os.Looper',
        'java.util.concurrent.Executor',
        'java.lang.Runnable',
        'androidx.core.content.ContextCompat',
        'androidx.core.content.FileProvider',
        'io.flutter.embedding.engine.FlutterEngine',
        'io.flutter.embedding.engine.plugins.FlutterPlugin',
        'io.flutter.embedding.engine.plugins.PluginRegistry',
        'io.flutter.embedding.engine.plugins.activity.ActivityAware',
        'io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding',
        'io.flutter.plugin.common.PluginRegistry',
      ],
    );
