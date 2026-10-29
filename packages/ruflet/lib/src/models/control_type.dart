import 'control.dart';

/// Legacy and transitional protocol names normalized to one logical control.
///
/// Renderers must branch on platform, never on a Material/Cupertino wire name.
/// The aliases remain accepted so existing applications continue to load while
/// new SDKs emit only the canonical names.
const Map<String, String> _controlTypeAliases = {
  "AdaptiveAlertDialog": "AlertDialog",
  "CupertinoAlertDialog": "AlertDialog",
  "AdaptiveAppBar": "AppBar",
  "CupertinoAppBar": "AppBar",
  "AdaptiveButton": "Button",
  "ElevatedButton": "Button",
  "CupertinoButton": "Button",
  "CupertinoFilledButton": "FilledButton",
  "CupertinoTintedButton": "FilledTonalButton",
  "AdaptiveCheckbox": "Checkbox",
  "CupertinoCheckbox": "Checkbox",
  "AdaptiveRadio": "Radio",
  "CupertinoRadio": "Radio",
  "AdaptiveSlider": "Slider",
  "CupertinoSlider": "Slider",
  "AdaptiveSwitch": "Switch",
  "CupertinoSwitch": "Switch",
  "AdaptiveTextField": "TextField",
  "CupertinoTextField": "TextField",
  "CupertinoActivityIndicator": "ProgressRing",
  "CupertinoFormRow": "FormRow",
  "CupertinoFormSection": "ListSection",
  "CupertinoListSection": "ListSection",
  "CupertinoListTile": "ListTile",
  "CupertinoNavigationBar": "NavigationBar",
  "CupertinoSegmentedButton": "SegmentedButton",
  "CupertinoSlidingSegmentedButton": "SegmentedButton",
  "CupertinoContextMenu": "ContextMenu",
  "CupertinoContextMenuAction": "ContextMenuAction",
  "PopupMenuItem": "ContextMenuAction",
  "CupertinoBottomSheet": "BottomSheet",
  "CupertinoActionSheet": "ActionSheet",
  "CupertinoActionSheetAction": "ActionSheetAction",
  "CupertinoDatePicker": "DatePicker",
  "CupertinoDialogAction": "Button",
  "CupertinoPicker": "Picker",
  "CupertinoTimerPicker": "TimerPicker",
  "DropdownM2": "Dropdown",
};

String canonicalControlType(String type) => _controlTypeAliases[type] ?? type;

/// Properties a legacy wire alias implies. Clients from before ruflet
/// b9e52ff7 send a Cupertino wire name where the canonical type now takes a
/// declared property, so renderers branch on the property, never on the
/// wire name.
const Map<String, Map<String, Object?>> _controlTypeAliasProperties = {
  "CupertinoSlidingSegmentedButton": {"sliding": true},
};

Map<String, Object?> controlTypeAliasProperties(String type) =>
    _controlTypeAliasProperties[type] ?? const {};

extension CanonicalControlType on Control {
  String get canonicalType => canonicalControlType(type);
}
