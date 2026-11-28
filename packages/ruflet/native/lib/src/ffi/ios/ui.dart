// The key window, the top view controller, and presenting/dismissing view
// controllers. UIKit is main-thread only; these run inline on main.
import 'async_blocks.dart';
import 'msg.dart';

// UISceneActivationState.
const _foregroundActive = 0;
const _foregroundInactive = 1;

List<Obj> _array(Obj array) => [
      for (var i = 0, n = msgULong(array, sel('count')); i < n; i++)
        msgObjULong(array, sel('objectAtIndex:'), i)
    ];

/// The key window of the foreground-active window scene (the template uses
/// UIApplicationSceneManifest), falling back to an inactive foreground scene
/// and then to the app delegate's window. Null before any window exists.
Obj? keyWindow() {
  final app = msgObj(cls('UIApplication'), sel('sharedApplication'));
  final scenes = _array(msgObj(msgObj(app, sel('connectedScenes')),
      sel('allObjects')));
  final windowScene = cls('UIWindowScene');
  for (final state in [_foregroundActive, _foregroundInactive]) {
    for (final scene in scenes) {
      if (!isKindOf(scene, windowScene)) continue;
      if (msgLong(scene, sel('activationState')) != state) continue;
      final windows = _array(msgObj(scene, sel('windows')));
      for (final window in windows) {
        if (msgBool(window, sel('isKeyWindow'))) return window;
      }
      if (windows.isNotEmpty) return windows.first;
    }
  }
  final delegate = msgObj(app, sel('delegate'));
  if (delegate != nil && respondsTo(delegate, 'window')) {
    final window = msgObj(delegate, sel('window'));
    if (window != nil) return window;
  }
  return null;
}

/// The view controller on top: the key window's root view controller,
/// followed down its presentedViewController chain.
Obj? topViewController() {
  final window = keyWindow();
  if (window == null) return null;
  var controller = msgObj(window, sel('rootViewController'));
  if (controller == nil) return null;
  while (true) {
    final presented = msgObj(controller, sel('presentedViewController'));
    if (presented == nil || msgBool(presented, sel('isBeingDismissed'))) {
      return controller;
    }
    controller = presented;
  }
}

// UIKit calls completions from the run loop: AsyncBlock (spike S8). The
// block closes itself after its one call.
AsyncBlock? _completion(void Function()? completion) {
  if (completion == null) return null;
  late final AsyncBlock block;
  block = AsyncBlock.voidCallback(() {
    block.close();
    completion();
  });
  return block;
}

/// `[presenter presentViewController:controller animated:completion:]`.
/// [completion] runs on a later event-loop turn.
void presentViewController(Obj presenter, Obj controller,
    {bool animated = true, void Function()? completion}) {
  final block = _completion(completion);
  msgVoidObjBoolObj(presenter, sel('presentViewController:animated:completion:'),
      controller, animated, block?.pointer ?? nil);
}

/// `[controller dismissViewControllerAnimated:completion:]`. UIKit calls the
/// completion on the main thread.
void dismissViewController(Obj controller,
    {bool animated = true, void Function()? completion}) {
  final block = _completion(completion);
  msgVoidBoolObj(controller, sel('dismissViewControllerAnimated:completion:'),
      animated, block?.pointer ?? nil);
}
