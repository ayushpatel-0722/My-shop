import 'storage_persistence_types.dart';

export 'storage_persistence_types.dart';

/// Android, iOS and desktop: no browser storage to make persistent.
StoragePersistenceApi createStoragePersistence() => _NoPersistence();

class _NoPersistence implements StoragePersistenceApi {
  @override
  Future<bool?> isPersisted() async => null;

  @override
  Future<PersistenceResult> request() async => PersistenceResult.unsupported;
}
