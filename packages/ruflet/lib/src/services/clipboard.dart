import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import '../ruflet_service.dart';
import '../utils/images.dart';
import '../utils/invoke.dart';

class ClipboardService extends RufletService {
  ClipboardService({required super.control});

  @override
  void init() {
    super.init();
    debugPrint("ClipboardService(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void update() {
    debugPrint("ClipboardService(${control.id}).update: ${control.properties}");
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("ClipboardService.$name($args)");
    switch (name) {
      case "set":
        final data = requireInvokeArg(args, "data", "Clipboard.set");
        await Clipboard.setData(ClipboardData(text: data.toString()));
        return;
      case "get":
        var data = await Clipboard.getData(Clipboard.kTextPlain);
        return data?.text;
      case "set_image":
        await Pasteboard.writeImage(convertToUint8List(
            requireInvokeArg(args, "data", "Clipboard.set_image")));
        return;
      case "get_image":
        return await Pasteboard.image;
      case "set_files":
        final value = requireInvokeArg(args, "files", "Clipboard.set_files");
        if (value is! List) {
          throw ArgumentError('Clipboard.set_files requires "files" to be a list');
        }
        final files =
            value.map((f) => f.toString()).toList(growable: false);
        return await Pasteboard.writeFiles(files);
      case "get_files":
        return await Pasteboard.files();
      default:
        throw Exception("Unknown Clipboard method: $name");
    }
  }

  @override
  void dispose() {
    debugPrint("ClipboardService(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }
}
