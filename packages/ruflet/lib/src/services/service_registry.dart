import 'package:flutter/foundation.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import 'service_binding.dart';

class ServiceRegistry {
  final Control control;
  final String propertyName;
  final RufletBackend backend;
  final Map<int, ServiceBinding> _services = {};

  ServiceRegistry(
      {required this.control,
      required this.propertyName,
      required this.backend}) {
    debugPrint("Init service registry: ${control.id}");
    control.addListener(_onServicesUpdated);
    _onServicesUpdated();
  }

  void _onServicesUpdated() {
    var serviceControls = control.children(propertyName);
    debugPrint("_onServicesUpdated(${serviceControls.length})");

    // newly added services, and services Ruby re-sent as new objects
    for (var serviceControl in serviceControls) {
      final binding = _services[serviceControl.id];
      if (binding != null && binding.control.type == serviceControl.type) {
        binding.rebind(serviceControl);
      } else {
        binding?.dispose();
        _services[serviceControl.id] =
            ServiceBinding(control: serviceControl, backend: backend);
      }
    }

    // removed services
    for (var serviceId in _services.keys.toList()) {
      if (!serviceControls
          .any((serviceControl) => serviceControl.id == serviceId)) {
        _services[serviceId]!.dispose();
        _services.remove(serviceId);
      }
    }
  }

  void dispose() {
    control.removeListener(_onServicesUpdated);
    for (var service in _services.values) {
      service.dispose();
    }
    _services.clear();
  }
}
