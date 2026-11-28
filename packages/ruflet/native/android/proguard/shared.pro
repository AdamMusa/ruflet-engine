# Classes and members the shared Android layer (lib/src/ffi/android) reaches
# only over JNI, so R8 cannot see that they are used. Flutter's own rules
# do not keep the embedding (release smoke, spike S6: without these,
# FlutterEngine is renamed and engineForId fails with
# ClassNotFoundException). Feature-specific keeps live in
# features/<feature>.pro.
-keep class io.flutter.embedding.engine.FlutterEngine {
    public static io.flutter.embedding.engine.FlutterEngine engineForId(long);
    public io.flutter.embedding.engine.plugins.PluginRegistry getPlugins();
    public long getEngineId();
}
-keep interface io.flutter.embedding.engine.plugins.PluginRegistry { *; }
-keep interface io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding {
    public android.content.Context getApplicationContext();
}
-keep interface io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }
-keep interface io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding { *; }
-keep interface io.flutter.plugin.common.PluginRegistry$ActivityResultListener { *; }
-keep interface io.flutter.plugin.common.PluginRegistry$RequestPermissionsResultListener { *; }
-keep interface io.flutter.plugin.common.PluginRegistry$NewIntentListener { *; }
