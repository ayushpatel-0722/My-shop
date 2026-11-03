import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'storage_persistence_types.dart';

export 'storage_persistence_types.dart';

/// Browser implementation using `navigator.storage.persist()`.
StoragePersistenceApi createStoragePersistence() => _WebPersistence();

class _WebPersistence implements StoragePersistenceApi {
  bool get _supported {
    try {
      // Older browsers and some private modes have no StorageManager.
      return (web.window.navigator as JSObject).has('storage');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool?> isPersisted() async {
    if (!_supported) return null;
    try {
      return (await web.window.navigator.storage.persisted().toDart).toDart;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PersistenceResult> request() async {
    if (!_supported) return PersistenceResult.unsupported;
    try {
      final granted =
          (await web.window.navigator.storage.persist().toDart).toDart;
      return granted ? PersistenceResult.granted : PersistenceResult.denied;
    } catch (_) {
      return PersistenceResult.error;
    }
  }
}
