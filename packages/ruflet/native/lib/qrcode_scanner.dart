/// QR code scanner for Ruflet over FFI: the native part of ruflet_qrcode_scanner.
///
/// `ruflet_qrcode_scanner` registers this library's [Extension]; it serves only this
/// feature, so apps that do not select the extension carry none of its code.
library;

import 'src/extension.dart';
import 'src/qrcode_scanner/feature.dart';

export 'src/extension.dart' show RufletNativeExtension;

/// The QR code scanner extension. The wrapper package passes its current service and
/// widget for the platforms where this feature does not run natively.
class Extension extends RufletNativeExtension {
  Extension({super.offPlatformService, super.offPlatformWidget})
      : super.features(const [qrcodeScannerFeature]);
}
