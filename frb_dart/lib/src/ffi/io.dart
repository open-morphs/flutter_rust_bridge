import 'dart:ffi' as ffi;
import 'dart:ffi';
export 'dart:ffi' show NativePort, DynamicLibrary;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'stub.dart' show FlutterRustBridgeWireBase;
export 'stub.dart'
    show castInt, castNativeBigInt, FlutterRustBridgeWireBase, WasmModule;

/// Abstraction over a Dart SendPort and a JS MessagePort.
typedef NativePortType = int;
typedef ExternalLibrary = ffi.DynamicLibrary;
typedef DartPostCObject = ffi.Pointer<
    ffi.NativeFunction<ffi.Bool Function(ffi.Int64, ffi.Pointer<ffi.Void>)>>;

extension StoreDartPostCObjectExt on FlutterRustBridgeWireBase {
  void storeDartPostCObject() {
    store_dart_post_cobject(ffi.NativeApi.postCObject.cast());
  }
}

// NOTE for maintainer: Please manually keep in sync with [WireSyncReturnStruct] in Rust
/// This class is only for internal usage.
class WireSyncReturnStruct extends ffi.Struct {
  /// Not to be used by normal users, but has to be public for generated code
  external ffi.Pointer<ffi.Uint8> ptr;

  /// Not to be used by normal users, but has to be public for generated code
  @ffi.Int32()
  external int len;

  /// Not to be used by normal users, but has to be public for generated code
  @ffi.Uint8()
  external int success;

  Uint8List get buffer => Uint8List.fromList(ptr.asTypedList(len));
  bool get isSuccess => success > 0;
}

/// An opaque pointer to a native C or Rust type.
/// Recipients of this type should call [dispose] at some point during runtime.
abstract class FrbOpaque implements Finalizable {
  /// Pointer to this opaque Rust type.
  ffi.Pointer<ffi.Void> _ptr;

  /// A native finalizer rust opaque type.
  /// Is static for each frb api class instance.
  NativeFinalizer get staticFinalizer;

  /// Rust type specific drop function.
  ///
  /// This function should never be called manually.
  void Function(ffi.Pointer<ffi.Void>) get dropFn;

  /// Rust type specific share function.
  ///
  /// This function should never be called manually.
  ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>) get shareFn;

  /// This constructor should never be called manually.
  @internal
  FrbOpaque.unsafe(int ptr, int size) : _ptr = ffi.Pointer.fromAddress(ptr) {
    assert(ptr > 0);
    staticFinalizer.attach(this, _ptr, detach: this, externalSize: size);
  }

  /// Call Rust destructors on the backing memory of this pointer.
  ///
  /// This function should be run at least once during the lifetime of the
  /// program, and can be run many times.
  ///
  /// When passed into a Rust function, Rust enacts *shared ownership*,
  /// if this pointer is shared with Rust when [dispose] is called,
  /// ownership is fully transferred to Rust else this pointer is cleared.
  void dispose() {
    if (!isStale()) {
      var ptr = _ptr;
      _ptr = Pointer.fromAddress(0);

      staticFinalizer.detach(this);
      dropFn(ptr);
    }
  }

  /// Increments inner reference counter and returns pointer to the underlying
  /// Rust object.
  ///
  /// Throws a [StateError] if called after [dispose].
  @internal
  ffi.Pointer<ffi.Void> share() {
    if (!isStale()) {
      return shareFn(_ptr);
    } else {
      throw StateError('Use after dispose.');
    }
  }

  /// Checks whether [dispose] has been called at any point during the lifetime
  /// of this pointer. This does not guarantee that the backing memory has
  /// actually been reclaimed.
  bool isStale() => _ptr.address == 0;
}
