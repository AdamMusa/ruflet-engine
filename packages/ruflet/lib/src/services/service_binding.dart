import '../ruflet_backend.dart';
import '../ruflet_service.dart';
import '../models/control.dart';

class ServiceBinding {
  Control _control;
  final RufletBackend backend;
  RufletService? _service;

  Control get control => _control;

  ServiceBinding({required Control control, required this.backend})
      : _control = control {
    for (var extension in backend.extensions) {
      _service = extension.createService(control);
      if (_service != null) {
        break;
      }
    }
    if (_service == null) {
      throw Exception("Unknown service: ${control.type}");
    }
    _service?.init();
    // A service registers its invoke listeners in init(), if it has any on
    // this platform; methods it does not handle now fail fast.
    control.attach();
    control.addListener(_onControlUpdated);
  }

  /// Moves the running service to [next], a new object Ruby sent for the
  /// same service.
  ///
  /// Ruby re-sends the whole services list whenever one is added or removed
  /// (`page.services << x`), so every other service arrives again as a new
  /// [Control] with the same id. The service keeps running (an audio player
  /// keeps playing, a stream stays subscribed); its invoke listeners, its
  /// attachment and its update listener move to [next], where Ruby's invokes
  /// and property patches now arrive. When [next] carries different
  /// properties the service applies them, as it would for a property patch.
  void rebind(Control next) {
    final previous = _control;
    if (identical(next, previous)) return;
    previous.removeListener(_onControlUpdated);
    previous.moveInvokeMethodListenersTo(next);
    next.attach();
    previous.detach();
    _control = next;
    _service?.control = next;
    next.addListener(_onControlUpdated);
    if (previous != next) {
      _service?.update();
    }
  }

  void dispose() {
    _control.removeListener(_onControlUpdated);
    _control.detach();
    _service?.dispose();
  }

  void _onControlUpdated() {
    _service?.update();
  }
}
