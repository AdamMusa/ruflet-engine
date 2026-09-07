# Ruflet Engine

The Flutter rendering engine and extension packages for Ruby applications built
with Ruflet. One Ruby control protocol selects independent Cupertino rendering
on iOS/macOS and Material rendering on Android/Windows/Linux.

## Packages

`packages/ruflet` is the core `package:ruflet/ruflet.dart` library. The sibling
`ruflet_*` packages provide optional controls and services. Their local path
dependencies include maintained Markdown, math, and media-kit-video forks.

The engine supports the native byte-message channel used by Ruflet `--self`
and `--self --full`; the Ruby VM is distributed separately by the Ruflet runtime.
Application code belongs in Ruby, not in the generated Flutter client.

## Development

```sh
cd packages/ruflet
flutter pub get
flutter test
flutter analyze lib test
```

Run the tests in each extension package when changing its renderer. Add layout
and attribute assertions, not just successful mount checks. Check both platform
designs and preserve application-specified geometry.

This repository is the source of truth for the Flutter engine and extensions.
`ruflet-template` carries a generated, commit-pinned distribution. Do not patch
an application's `build/client` directory or change Ruby application layouts
to compensate for engine bugs.

## Attribution

This distribution was extracted from Ruflet Template commit
`5cbd01a`, whose core derives from Flet commit
`7cce34b72837bc4a3e8518bb24e10c530c91c29b`, with Ruflet's namespace,
platform-renderer separation, and in-process transport changes.

The core's Apache-2.0 license and every extension/vendor license remain in their
package directories. Package-specific licenses govern their respective code;
this repository does not relicense third-party dependencies. Upstream links and
copyright notices are attribution, not legacy runtime dependencies.
