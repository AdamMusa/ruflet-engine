// libdispatch over dart:ffi (part of libSystem, always loaded).
import 'dart:ffi';

final DynamicLibrary _process = DynamicLibrary.process();

/// `dispatch_time_t DISPATCH_TIME_NOW`.
const int dispatchTimeNow = 0;

/// `dispatch_function_t`: `void (*)(void *context)`.
typedef DispatchFunction = Void Function(Pointer<Void> context);

/// `void dispatch_async_f(dispatch_queue_t, void *, dispatch_function_t)`.
final void Function(Pointer<Void> queue, Pointer<Void> context,
        Pointer<NativeFunction<DispatchFunction>> work) dispatchAsyncF =
    _process.lookupFunction<
        Void Function(Pointer<Void>, Pointer<Void>,
            Pointer<NativeFunction<DispatchFunction>>),
        void Function(Pointer<Void>, Pointer<Void>,
            Pointer<NativeFunction<DispatchFunction>>)>('dispatch_async_f');

/// `void dispatch_after_f(dispatch_time_t, dispatch_queue_t, void *, dispatch_function_t)`.
final void Function(int when, Pointer<Void> queue, Pointer<Void> context,
        Pointer<NativeFunction<DispatchFunction>> work) dispatchAfterF =
    _process.lookupFunction<
        Void Function(Uint64, Pointer<Void>, Pointer<Void>,
            Pointer<NativeFunction<DispatchFunction>>),
        void Function(int, Pointer<Void>, Pointer<Void>,
            Pointer<NativeFunction<DispatchFunction>>)>('dispatch_after_f');

/// `dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta)`.
final int Function(int when, int deltaNanoseconds) dispatchTime =
    _process.lookupFunction<Uint64 Function(Uint64, Int64),
        int Function(int, int)>('dispatch_time');

/// `dispatch_queue_global_t dispatch_get_global_queue(intptr_t, uintptr_t)`.
final Pointer<Void> Function(int identifier, int flags) dispatchGetGlobalQueue =
    _process.lookupFunction<Pointer<Void> Function(IntPtr, UintPtr),
        Pointer<Void> Function(int, int)>('dispatch_get_global_queue');

/// QOS_CLASS_DEFAULT, for dispatchGetGlobalQueue.
const int qosClassDefault = 0x15;
