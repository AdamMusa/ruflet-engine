// For release/profile smoke runs (SPEC §8.3):
//   flutter drive --release --driver=test_driver/integration_test.dart \
//     --target=integration_test/<file>_test.dart -d <device>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
