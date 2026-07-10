import 'package:hive/hive.dart';

/// One queued cloud write. Immutable snapshot of a Hive entry.
class SyncQueueEntry {
  final int key;
  final String table;
  final String recordId;
  final Map<String, dynamic> data;
  final int attempts;
  final String? lastError;
  final int version;

  SyncQueueEntry({
    required this.key,
    required this.table,
    required this.recordId,
    required this.data,
    required this.attempts,
    required this.version,
    this.lastError,
  });

  factory SyncQueueEntry.fromBox(int key, Map raw) => SyncQueueEntry(
        key: key,
        table: raw['table'] as String,
        recordId: raw['recordId'] as String,
        data: Map<String, dynamic>.from(raw['data'] as Map),
        attempts: raw['attempts'] as int? ?? 0,
        lastError: raw['lastError'] as String?,
        version: raw['version'] as int? ?? 1,
      );
}

/// Persistent FIFO queue of pending cloud writes.
///
/// Entries are removed only after the cloud write is confirmed. Re-enqueueing
/// a record coalesces IN PLACE (same Hive key) so the queue stays bounded and
/// FIFO order still reflects creation order — a package can never be flushed
/// before the customer it references.
///
/// Coalescing deliberately resets `attempts` and `lastError`: fresh data gets
/// a fresh retry clock. Flush loops must confirm removals with
/// [removeIfVersion] using the snapshotted entry's [SyncQueueEntry.version],
/// so an edit coalesced mid-push is never dropped unsynced.
///
/// The box is resolved through a getter so the active box can change when the
/// storage namespace switches (sign-in/sign-out) without rebuilding the queue.
class SyncQueue {
  final Box Function() _boxGetter;

  SyncQueue(this._boxGetter);

  Box get _box => _boxGetter();

  int get length => _box.length;
  bool get isEmpty => _box.isEmpty;

  Future<void> enqueue({
    required String table,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    final value = {
      'table': table,
      'recordId': recordId,
      'data': data,
      'attempts': 0,
      'lastError': null,
      'version': 1,
      'enqueuedAt': DateTime.now().toIso8601String(),
    };
    for (final key in _box.keys) {
      final raw = _box.get(key) as Map;
      if (raw['table'] == table && raw['recordId'] == recordId) {
        final currentVersion = raw['version'] as int? ?? 1;
        value['version'] = currentVersion + 1;
        await _box.put(key, value);
        return;
      }
    }
    await _box.add(value);
  }

  List<SyncQueueEntry> entries() {
    final keys = _box.keys.cast<int>().toList()..sort();
    return [
      for (final k in keys) SyncQueueEntry.fromBox(k, _box.get(k) as Map),
    ];
  }

  Set<String> pendingRecordIds(String table) => {
        for (final e in entries())
          if (e.table == table) e.recordId,
      };

  Future<void> remove(int key) => _box.delete(key);

  /// Remove the entry at [entry.key] only if the box still holds the SAME
  /// record (table + recordId) at the SAME version as the snapshot. Guards
  /// against both mid-push coalesced edits and stale snapshots surviving a
  /// namespace switch, where integer keys restart in a fresh box. Returns
  /// true when removed; when false, whatever lives at that key stays queued.
  Future<bool> removeIfVersion(SyncQueueEntry entry) async {
    final raw = _box.get(entry.key);
    if (raw == null) return false;
    final map = raw as Map;
    if (map['table'] != entry.table || map['recordId'] != entry.recordId) {
      return false;
    }
    if ((map['version'] as int? ?? 1) != entry.version) return false;
    await _box.delete(entry.key);
    return true;
  }

  /// Marks a failed push attempt, but only if the box still holds the same
  /// record at the same version — a coalesced or foreign entry is left
  /// alone. Does not bump [SyncQueueEntry.version]: version tracks data
  /// changes only, not delivery attempts.
  Future<void> recordFailure(SyncQueueEntry entry, String message) async {
    final raw = _box.get(entry.key);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['table'] != entry.table || map['recordId'] != entry.recordId) {
      return;
    }
    if ((map['version'] as int? ?? 1) != entry.version) return;
    map['attempts'] = (map['attempts'] as int? ?? 0) + 1;
    map['lastError'] = message;
    await _box.put(entry.key, map);
  }

  /// The oldest recorded failure, for surfacing in the sync status UI.
  String? get firstError {
    for (final e in entries()) {
      if (e.lastError != null) return e.lastError;
    }
    return null;
  }
}
