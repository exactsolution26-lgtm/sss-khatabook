/// Cloud configuration must never expose the shared offline workspace.
/// Set cloud readiness only after authenticated tenant storage/sync is implemented
/// and verified; it is intentionally not a caller-selectable bypass flag.
class BackendMode {
  static bool localOnly(String url,String key) {
    if(url.isEmpty != key.isEmpty) throw StateError('Incomplete backend configuration');
    return url.isEmpty && key.isEmpty;
  }
}
