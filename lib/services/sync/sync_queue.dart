import 'package:hive/hive.dart';

/// One queued cloud write. Immutable snapshot of a Hive entry.
class SyncQueueEntry {
  final int key;
  final String table;
  final String recordId;
  final Map<String, dynamic> data;
  final int attempts;
  final String? lastError;

  SyncQueueEntry({
    required this.key,
    required this.table,
    required this.recordId,
    required this.data,
    required this.attempts,
    this.lastError,
  });

  factory SyncQueueEntry.fromBox(int key, Map raw) => SyncQueueEntry(
        key: key,
        table: raw['table'] as String,
        recordId: raw['recordId'] as String,
        data: Map<String, dynamic>.from(raw['data'] as Map),
        attempts: raw['attempts'] as int? ?? 0,
        lastError: raw['lastError'] as String?,
      );
}

/// Persistent FIFO queue of pending cloud writes.
///
/// Entries are removed only after the cloud write is confirmed. Re-enqueueing
/// a record coalesces IN PLACE (same Hive key) so the queue stays bounded and
/// FIFO order still reflects creation order — a package can never be flushed
/// before the customer it references.
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
      'enqueuedAt': DateTime.now().toIso8601String(),
    };
    for (final key in _box.keys) {
      final raw = _box.get(key) as Map;
      if (raw['table'] == table && raw['recordId'] == recordId) {
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

  Future<void> recordFailure(int key, String message) async {
    final raw = Map<String, dynamic>.from(_box.get(key) as Map);
    raw['attempts'] = (raw['attempts'] as int? ?? 0) + 1;
    raw['lastError'] = message;
    await _box.put(key, raw);
  }

  /// The oldest recorded failure, for surfacing in the sync status UI.
  String? get firstError {
    for (final e in entries()) {
      if (e.lastError != null) return e.lastError;
    }
    return null;
  }
}
