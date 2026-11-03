/// What the browser said when asked to keep this site's storage.
enum PersistenceResult {
  /// Storage is now persistent (the browser will not evict it on its own).
  granted,

  /// The browser refused; storage may still be evicted under pressure.
  denied,

  /// This platform or browser has no such API.
  unsupported,

  /// The request failed.
  error,
}

/// Asks the browser to keep this site's storage. Agreeing to caching and the
/// browser granting persistence are separate: callers must look at the result.
abstract class StoragePersistenceApi {
  /// Whether storage is already persistent (null when unknown).
  Future<bool?> isPersisted();

  /// Requests persistence.
  Future<PersistenceResult> request();
}
