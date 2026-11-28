// The exceptions torch_light 1.1.0 threw, with the same names and the same
// toString(). The engine sends `e.toString()` back to Ruby as the invoke
// error, so keeping these byte for byte keeps every reply Ruby sees unchanged.

/// The camera is used by another process, so the torch cannot be turned on.
class EnableTorchExistentUserException implements Exception {
  String? message;
  EnableTorchExistentUserException({this.message});

  @override
  String toString() => message != null
      ? "[EnableTorchExistentUserException: $message]"
      : "[EnableTorchExistentUserException]";
}

/// An error occurred while turning the torch on (or checking for one).
class EnableTorchException implements Exception {
  String? message;
  EnableTorchException({this.message});

  @override
  String toString() => message != null
      ? "[EnableTorchException: $message]"
      : "[EnableTorchException]";
}

/// The device has no torch, so it cannot be turned on.
class EnableTorchNotAvailableException implements Exception {
  String? message;
  EnableTorchNotAvailableException({this.message});

  @override
  String toString() => message != null
      ? "[EnableTorchNotAvailableException: $message]"
      : "[EnableTorchNotAvailableException]";
}

/// The camera is used by another process, so the torch cannot be turned off.
class DisableTorchExistentUserException implements Exception {
  String? message;
  DisableTorchExistentUserException({this.message});

  @override
  String toString() => message != null
      ? "[DisableTorchExistentUserException: $message]"
      : "[DisableTorchExistentUserException]";
}

/// An error occurred while turning the torch off.
class DisableTorchException implements Exception {
  String? message;
  DisableTorchException({this.message});

  @override
  String toString() => message != null
      ? "[DisableTorchException: $message]"
      : "[DisableTorchException]";
}

/// The device has no torch, so it cannot be turned off.
class DisableTorchNotAvailableException implements Exception {
  String? message;
  DisableTorchNotAvailableException({this.message});

  @override
  String toString() => message != null
      ? "[DisableTorchNotAvailableException: $message]"
      : "[DisableTorchNotAvailableException]";
}
