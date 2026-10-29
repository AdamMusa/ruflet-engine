// The controls migrated onto the shared control core. One entry per
// migration PR; control_core_contract_test.dart checks every entry against
// rules C1–C7 (see test/architecture/README.md).
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoButton;
import 'package:flutter/material.dart' as material show IconButton;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        ElevatedButton,
        FilledButton,
        ListTile,
        Offset,
        OutlinedButton,
        TextButton;
import 'package:flutter_test/flutter_test.dart' show find;
import 'package:ruflet/ruflet.dart' show RufletExtension;
import 'package:ruflet/src/controls/button_core.dart';
import 'package:ruflet/src/controls/icon_button_core.dart';
import 'package:ruflet/src/controls/list_tile_core.dart';
import 'package:ruflet/src/controls/progress_ring_core.dart';
import 'package:ruflet/src/core/control_spec.dart';
import 'package:ruflet/src/widgets/ruflet_cupertino_list_tile.dart';

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
  for (final (index, spec, material) in [
    (0, buttonSpec, ElevatedButton),
    (1, filledButtonSpec, FilledButton),
    (2, filledTonalButtonSpec, FilledButton),
    (3, outlinedButtonSpec, OutlinedButton),
    (4, textButtonSpec, TextButton),
  ])
    MigratedControl(
      spec: spec,
      entry: 'lib/src/controls/adaptive_button.dart',
      core: 'lib/src/controls/button_core.dart',
      propsClass: 'ButtonProps',
      skins: {
        Skin.material: 'lib/src/controls/button.dart',
        Skin.cupertino: 'lib/src/controls/cupertino_button_skin.dart',
      },
      // A Button inside an AlertDialog renders as an iOS dialog action.
      helpers: {
        Skin.cupertino: ['lib/src/controls/cupertino_dialog_action.dart'],
      },
      fixture: () => {
        '_c': 'Column',
        '_i': 630 + index * 2,
        'controls': [
          {'_c': spec.wireType, '_i': 631 + index * 2, 'content': 'Press'},
        ],
      },
      nativeWidgets: {Skin.material: material, Skin.cupertino: CupertinoButton},
      samples: {
        'clip_behavior': 'antiAlias',
        'size': 'medium',
        'min_size': {'width': 40.0, 'height': 40.0},
        'style': {'bgcolor': '#eeeeee'},
        'opacity_on_click': 0.5,
      },
      parityScript: [
        SnapshotStep.tapNative(),
        SnapshotStep.tapText('Press'),
        _longPress('Press'),
        _hover(),
        SnapshotStep.tab(),
        SnapshotStep.unfocus(),
      ],
    ),
  for (final (index, spec) in [
    (0, iconButtonSpec),
    (1, filledIconButtonSpec),
    (2, filledTonalIconButtonSpec),
    (3, outlinedIconButtonSpec),
  ])
    MigratedControl(
      spec: spec,
      entry: 'lib/src/controls/icon_button.dart',
      core: 'lib/src/controls/icon_button_core.dart',
      propsClass: 'IconButtonProps',
      skins: {
        Skin.material: 'lib/src/controls/material_icon_button.dart',
        Skin.cupertino: 'lib/src/controls/cupertino_button.dart',
      },
      fixture: () => {
        '_c': 'Column',
        '_i': 650 + index * 2,
        'controls': [
          {'_c': spec.wireType, '_i': 651 + index * 2, 'icon': 0x10000},
        ],
      },
      nativeWidgets: {
        Skin.material: material.IconButton,
        Skin.cupertino: CupertinoButton,
      },
      samples: {
        'style': {'bgcolor': '#eeeeee'},
        'size_constraints': {'min_width': 40.0, 'min_height': 40.0},
        'visual_density': 'compact',
        'selected': false,
      },
      parityScript: [
        SnapshotStep.tapNative(),
        _longPressCenter(),
        _hover(),
        SnapshotStep.tab(),
        SnapshotStep.unfocus(),
      ],
    ),
  MigratedControl(
    spec: listTileSpec,
    entry: 'lib/src/controls/adaptive_list_tile.dart',
    core: 'lib/src/controls/list_tile_core.dart',
    propsClass: 'ListTileProps',
    skins: {
      Skin.material: 'lib/src/controls/list_tile.dart',
      Skin.cupertino: 'lib/src/controls/cupertino_list_tile.dart',
    },
    fixture: () => {
      '_c': 'Column',
      '_i': 690,
      'controls': [
        {
          '_c': 'ListTile',
          '_i': 691,
          'title': 'Tile',
          'subtitle': 'Details',
          'leading': 0x10000,
        },
      ],
    },
    nativeWidgets: {
      Skin.material: ListTile,
      Skin.cupertino: RufletCupertinoListTile,
    },
    samples: {
      'visual_density': 'compact',
      'style': 'list',
      'title_alignment': 'center',
    },
    parityScript: [
      SnapshotStep.tapNative(),
      _longPressCenter(),
      SnapshotStep.unfocus(),
    ],
  ),
  MigratedControl(
    spec: progressRingSpec,
    entry: 'lib/src/controls/adaptive_progress_ring.dart',
    core: 'lib/src/controls/progress_ring_core.dart',
    propsClass: 'ProgressRingProps',
    skins: {
      Skin.material: 'lib/src/controls/progress_ring.dart',
      Skin.cupertino: 'lib/src/controls/cupertino_activity_indicator.dart',
    },
    // Determinate, so the harness can settle it; labelled, so C7 compares
    // what both designs announce.
    fixture: () => {
      '_c': 'Column',
      '_i': 670,
      'controls': [
        {
          '_c': 'ProgressRing',
          '_i': 671,
          'value': 0.5,
          'semantics_label': 'Loading',
        },
      ],
    },
    nativeWidgets: {
      Skin.material: CircularProgressIndicator,
      Skin.cupertino: CupertinoActivityIndicator,
    },
    samples: {
      'stroke_cap': 'round',
      'size_constraints': {'min_width': 40.0, 'min_height': 40.0},
    },
    parityScript: [
      SnapshotStep.tapNative(),
      SnapshotStep.unfocus(),
    ],
  ),
];

SnapshotStep _longPressCenter() => SnapshotStep('long press', (c) async {
      await c.tester.longPress(c.finder.first);
      await c.tester.pumpAndSettle();
    });

SnapshotStep _longPress(String text) =>
    SnapshotStep('long press "$text"', (c) async {
      await c.tester.longPress(find.text(text));
      await c.tester.pumpAndSettle();
    });

/// A mouse pointer enters the control and leaves it again.
SnapshotStep _hover() => SnapshotStep('hover in and out', (c) async {
      final mouse = await c.tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(790, 590));
      await c.tester.pump();
      await mouse.moveTo(c.tester.getCenter(c.finder.first));
      await c.tester.pumpAndSettle();
      await mouse.moveTo(const Offset(790, 590));
      await c.tester.pumpAndSettle();
      await mouse.removePointer();
      await c.tester.pump();
    });
