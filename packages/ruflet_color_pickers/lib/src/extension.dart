import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';

import 'block_picker.dart';
import 'color_picker.dart';
import 'hue_ring_picker.dart';
import 'material_picker.dart';
import 'multiple_choice_block_picker.dart';
import 'slide_picker.dart';

class Extension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "ColorPicker":
        return ColorPickerControl(key: key, control: control);
      case "HueRingPicker":
        return HueRingPickerControl(key: key, control: control);
      case "SlidePicker":
        return SlidePickerControl(key: key, control: control);
      case "MaterialPicker":
        return MaterialPickerControl(key: key, control: control);
      case "BlockPicker":
        return BlockPickerControl(key: key, control: control);
      case "MultipleChoiceBlockPicker":
        return MultipleChoiceBlockPickerControl(key: key, control: control);
      default:
        return null;
    }
  }
}
