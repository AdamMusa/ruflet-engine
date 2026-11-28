// libSystem C APIs over dart:ffi.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

final DynamicLibrary _process = DynamicLibrary.process();

final int Function(Pointer<Utf8>, Pointer<Void>, Pointer<Size>, Pointer<Void>,
    int) _sysctlbyname = _process.lookupFunction<
    Int Function(Pointer<Utf8>, Pointer<Void>, Pointer<Size>, Pointer<Void>,
        Size),
    int Function(Pointer<Utf8>, Pointer<Void>, Pointer<Size>, Pointer<Void>,
        int)>('sysctlbyname');

/// A string sysctl value (for example `hw.machine`), or null.
String? sysctlString(String name) => using((arena) {
      final key = name.toNativeUtf8(allocator: arena);
      final length = arena<Size>();
      if (_sysctlbyname(key, nullptr, length, nullptr, 0) != 0) return null;
      final buffer = arena<Uint8>(length.value + 1);
      if (_sysctlbyname(key, buffer.cast(), length, nullptr, 0) != 0) {
        return null;
      }
      return buffer.cast<Utf8>().toDartString();
    });

/// An integer sysctl value (for example `hw.memsize`), or null.
int? sysctlInt(String name) => using((arena) {
      final key = name.toNativeUtf8(allocator: arena);
      final value = arena<Int64>();
      final length = arena<Size>()..value = sizeOf<Int64>();
      if (_sysctlbyname(key, value.cast(), length, nullptr, 0) != 0) {
        return null;
      }
      return length.value == sizeOf<Int32>()
          ? value.cast<Int32>().value
          : value.value;
    });

// struct utsname on Darwin: five char[256] fields (_SYS_NAMELEN).
const _nameLength = 256;

final int Function(Pointer<Uint8>) _uname = _process
    .lookupFunction<Int Function(Pointer<Uint8>), int Function(Pointer<Uint8>)>(
        'uname');

/// `uname(2)`, as device_info_plus reads it.
({String sysname, String nodename, String release, String version, String machine})?
    uname() => using((arena) {
          final buffer = arena<Uint8>(_nameLength * 5);
          if (_uname(buffer) != 0) return null;
          String field(int index) =>
              (buffer + index * _nameLength).cast<Utf8>().toDartString();
          return (
            sysname: field(0),
            nodename: field(1),
            release: field(2),
            version: field(3),
            machine: field(4),
          );
        });
