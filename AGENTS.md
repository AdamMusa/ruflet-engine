# Ruflet Flutter engine

This repository owns the Flutter core and extension packages under `packages/`.
The experimental native Swift renderer is a separate project; do not replace it
or edit generated native copies here.

- Keep Ruby control attributes and events intact across both platform renderers.
- Reproduce layout bugs with geometry/property assertions in Flutter tests.
- Test both Cupertino and Material paths for shared attribute fixes.
- Keep in-process transport independent from visual renderer selection.
- Preserve package licenses, copyright notices, and runtime font/assets.
- Do not copy build outputs, developer caches, credentials, or application data.
- Commit each complete feature or rendering fix separately.
- Template and application clients consume committed engine sources; do not fix
  bugs by editing generated copies or compensating in the Ruby application.
