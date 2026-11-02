// The controls migrated onto the shared control core. One entry per
// migration PR; control_core_contract_test.dart checks every entry against
// rules C1–C7 (see test/architecture/README.md).
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart' show Switch;
import 'package:ruflet/ruflet.dart' show RufletExtension;
import 'package:ruflet/src/controls/switch_core.dart';
import 'package:ruflet/src/core/control_spec.dart';

import '../support/control_snapshot.dart' show SnapshotStep;

class MigratedControl {
  MigratedControl({
    required this.spec,
    required this.entry,
    required this.core,
    required this.propsClass,
    required this.skins,
    required this.fixture,
    required this.nativeWidgets,
    this.helpers = const {},
    this.unexercisedEvents = const {},
    this.portInterface,
    this.samples = const {},
    this.parityScript = const [],
    this.extensions = _noExtensions,
  });

  final ControlSpec spec;
  String get wireType => spec.wireType;

  /// The registry entry file (`createWidget` keeps calling its class).
  final String entry;

  /// The `*_core.dart` library declaring the spec, props and core.
  final String core;

  /// The immutable props class in [core]; its parse plumbing is not counted
  /// as consumption by C4.
  final String propsClass;

  /// The skin library of each design.
  final Map<Skin, String> skins;

  /// Design-specific helper libraries a skin delegates to (C4 scans them
  /// with the skin).
  final Map<Skin, List<String>> helpers;

  /// The port interface every skin implements when a [MethodSpec] is a port.
  final String? portInterface;

  /// A wire tree that renders one instance; the control under test is its
  /// first node of [wireType] (e.g. a Radio inside a RadioGroup).
  final Map<String, dynamic> Function() fixture;

  /// C6: sample values by key, used instead of the generated ones.
  final Map<String, Object?> samples;

  /// C7: interactions whose recorded events must match on both designs. It
  /// must include [SnapshotStep.tapNative] and fire every core-sourced event.
  final List<SnapshotStep> parityScript;

  /// The native widget type each skin renders (what `tap native` taps).
  final Map<Skin, Type> nativeWidgets;

  /// Core-sourced events a parity script cannot drive, with the reason.
  final Map<String, String> unexercisedEvents;

  /// Extra extensions the fixture needs (test-only controls).
  final List<RufletExtension> Function() extensions;
}

List<RufletExtension> _noExtensions() => const [];

/// One line per migration, in migration order.
final List<MigratedControl> migratedControls = [
  MigratedControl(
    spec: switchSpec,
    entry: 'lib/src/controls/adaptive_switch.dart',
    core: 'lib/src/controls/switch_core.dart',
    propsClass: 'SwitchProps',
    skins: {
      Skin.material: 'lib/src/controls/switch.dart',
      Skin.cupertino: 'lib/src/controls/cupertino_switch.dart',
    },
    fixture: () => {
      '_c': 'Column',
      '_i': 600,
      'controls': [
        {'_c': 'Switch', '_i': 601, 'label': 'Toggle'},
      ],
    },
    nativeWidgets: {Skin.material: Switch, Skin.cupertino: CupertinoSwitch},
    samples: {'label_position': 'left'},
    parityScript: [
      SnapshotStep.tapNative(),
      SnapshotStep.semanticsTap(),
      SnapshotStep.tapText('Toggle'),
      SnapshotStep.tab(),
      SnapshotStep.unfocus(),
    ],
  ),
];
