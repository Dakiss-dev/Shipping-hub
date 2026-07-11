import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shipping_hub/services/sync/sync_queue.dart';

void main() {
  late Directory tempDir;
  late Box activeBox;
  late SyncQueue queue;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_queue_test');
    Hive.init(tempDir.path);
    activeBox = await Hive.openBox('sync_queue');
    queue = SyncQueue(() => activeBox);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  test('enqueue appends entries in FIFO order', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 1});
    await queue.enqueue(table: 'packages', recordId: 'p1', data: {'v': 1});
    final entries = queue.entries();
    expect(entries.map((e) => e.recordId).toList(), ['c1', 'p1']);
  });

  test('re-enqueueing a record coalesces in place, keeping its position', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 1});
    await queue.enqueue(table: 'packages', recordId: 'p1', data: {'v': 1});
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 2});
    final entries = queue.entries();
    expect(entries.length, 2);
    expect(entries.first.recordId, 'c1'); // still first — order preserved
    expect(entries.first.data['v'], 2); // but carries the latest data
  });

  test('remove deletes an entry; recordFailure tracks attempts and error', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {});
    final entry = queue.entries().single;
    await queue.recordFailure(entry, 'network down');
    final failed = queue.entries().single;
    expect(failed.attempts, 1);
    expect(failed.lastError, 'network down');
    expect(queue.firstError, 'network down');
    await queue.remove(failed.key);
    expect(queue.isEmpty, isTrue);
  });

  test('pendingRecordIds returns queued ids for one table only', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {});
    await queue.enqueue(table: 'packages', recordId: 'p1', data: {});
    expect(queue.pendingRecordIds('customers'), {'c1'});
    expect(queue.pendingRecordIds('shipments'), isEmpty);
  });

  test('removeIfVersion refuses to drop a version coalesced mid-push', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 1});
    final snapshot = queue.entries().single; // engine snapshots, starts push
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 2});
    final removed = await queue.removeIfVersion(snapshot);
    expect(removed, isFalse); // newer edit survives
    final current = queue.entries().single;
    expect(current.data['v'], 2);
    expect(await queue.removeIfVersion(current), isTrue);
    expect(queue.isEmpty, isTrue);
  });

  test('coalescing resets attempts and lastError, bumps version', () async {
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 1});
    final first = queue.entries().single;
    await queue.recordFailure(first, 'boom');
    await queue.enqueue(table: 'customers', recordId: 'c1', data: {'v': 2});
    final coalesced = queue.entries().single;
    expect(coalesced.attempts, 0);
    expect(coalesced.lastError, isNull);
    expect(coalesced.version, first.version + 1);
    expect(queue.firstError, isNull);
  });

  test('FIFO order holds numerically past ten entries', () async {
    for (var i = 0; i < 12; i++) {
      await queue.enqueue(table: 'customers', recordId: 'c$i', data: {'i': i});
    }
    expect(queue.entries().map((e) => e.recordId).toList(),
        [for (var i = 0; i < 12; i++) 'c$i']);
  });

  test('a stale snapshot from another box cannot touch the active box',
      () async {
    await queue.enqueue(table: 'customers', recordId: 'old-ns', data: {});
    final stale = queue.entries().single; // key 0 in the first box

    // Namespace switch: the getter now resolves to a fresh box whose
    // auto-increment keys restart at 0.
    activeBox = await Hive.openBox('sync_queue_b');
    await queue.enqueue(table: 'packages', recordId: 'new-ns', data: {});

    expect(await queue.removeIfVersion(stale), isFalse); // identity mismatch
    await queue.recordFailure(stale, 'ghost'); // must not stamp the new entry
    expect(queue.entries().single.lastError, isNull);
    expect(queue.length, 1);
  });
}
