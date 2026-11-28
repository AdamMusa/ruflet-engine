// NSNotificationCenter observers whose callback is a Dart closure.
import 'async_blocks.dart';
import 'main_queue.dart';
import 'msg.dart';

/// One `addObserverForName:object:queue:usingBlock:` registration.
///
/// Foundation calls the block on `NSOperationQueue.mainQueue` from the run
/// loop, outside any Dart task, so it is an [AsyncBlock] (spike S8): the
/// Dart callback runs on a later event-loop turn with the notification
/// retained for the duration of the callback.
class NotificationObserver {
  /// Observes [name] (an NSString pointer, for example a framework constant
  /// from `Frameworks.constant`) posted by [sender] (nil: any sender).
  NotificationObserver(Obj name, void Function(Obj notification) onNotification,
      {Obj? sender})
      : _block = AsyncBlock.obj(onNotification) {
    _token = retain(msgObj4Obj(
        _center,
        sel('addObserverForName:object:queue:usingBlock:'),
        name,
        sender ?? nil,
        mainOperationQueue,
        _block.pointer));
  }

  /// Observes the notification named [name] (a Dart string).
  NotificationObserver.named(
      String name, void Function(Obj notification) onNotification,
      {Obj? sender})
      : this(nsString(name), onNotification, sender: sender);

  static Obj get _center =>
      msgObj(cls('NSNotificationCenter'), sel('defaultCenter'));

  final AsyncBlock _block;
  late final Obj _token;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Removes the observer. After this the block is never called again.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    msgVoidObj(_center, sel('removeObserver:'), _token);
    release(_token);
    _block.close();
  }
}

/// `[[NSNotificationCenter defaultCenter] postNotificationName:object:]`.
void postNotification(Obj name, {Obj? sender}) => msgVoidObjObj(
    msgObj(cls('NSNotificationCenter'), sel('defaultCenter')),
    sel('postNotificationName:object:'),
    name,
    sender ?? nil);
