import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/services/connectivity_service.dart';
import 'package:jurnalmengajar/core/services/sync_queue_service.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';

class FakeJournalRepository implements JournalRepository {
  final List<JournalModel> created = [];
  final List<JournalModel> updated = [];
  bool shouldThrow = false;
  String? errorToThrow;

  @override
  Future<void> create(JournalModel model) async {
    if (shouldThrow) throw Exception(errorToThrow ?? 'Network error');
    created.add(model);
  }

  @override
  Future<void> update(JournalModel model) async {
    if (shouldThrow) throw Exception(errorToThrow ?? 'Network error');
    updated.add(model);
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<List<JournalModel>> getAll([String? schoolId]) async => [];

  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async => [];

  @override
  Future<JournalModel?> getJournalForSchedule(String scheduleId, {DateTime? date}) async => null;

  @override
  Future<void> verifyJournal(String journalId, String status, {String? rejectionNote}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('SyncQueueService (Local Outbox Pattern)', () {
    final syncQueue = SyncQueueService.instance;
    final connectivity = ConnectivityService.instance;
    late FakeJournalRepository fakeRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      connectivity.cancelTimersForTest();
      connectivity.reportOnline();
      fakeRepo = FakeJournalRepository();
      await syncQueue.clearQueue();
    });

    tearDown(() async {
      connectivity.cancelTimersForTest();
      await syncQueue.clearQueue();
    });

    test('1. Enqueue saat offline: data tersimpan di antrean dengan status pending', () async {
      connectivity.reportOffline();

      final journal = JournalModel(
        id: 'temp_001',
        scheduleId: 'sch_abc',
        date: DateTime(2026, 11, 23),
        teachingHour: 1,
        classId: 'cls_1',
        subjectId: 'sub_1',
        teacherId: 'tch_1',
        material: 'Materi Pengenalan Flutter',
        status: 'pending',
        isSyncPending: true,
      );

      final fakeImage = Uint8List.fromList([1, 2, 3, 4]);

      final item = await syncQueue.enqueueJournal(
        journal: journal,
        isUpdate: false,
        imageBytesList: [fakeImage],
        imageNamesList: ['bukti.jpg'],
      );

      expect(syncQueue.queueCount, 1);
      expect(syncQueue.hasPendingItems, isTrue);
      expect(syncQueue.isSchedulePendingSync('sch_abc'), isTrue);
      expect(item.base64Images.isNotEmpty, isTrue);
      expect(item.imageNames.first, 'bukti.jpg');
    });

    test('2. Process queue saat online: data otomatis terunggah ke repository dan antrean terhapus', () async {
      // Masukkan item saat offline
      connectivity.reportOffline();

      final journal = JournalModel(
        id: 'temp_002',
        scheduleId: 'sch_xyz',
        date: DateTime(2026, 11, 23),
        teachingHour: 2,
        classId: 'cls_2',
        subjectId: 'sub_2',
        teacherId: 'tch_2',
        material: 'Materi Algoritma Pemrograman',
        status: 'pending',
      );

      await syncQueue.enqueueJournal(
        journal: journal,
        isUpdate: false,
      );

      expect(syncQueue.queueCount, 1);

      // Simulasi: koneksi internet kembali online
      connectivity.reportOnline();

      // Jalankan sinkronisasi
      await syncQueue.processQueue(fakeRepo);

      // Antrean harus kosong karena sudah sukses terkirim ke repo
      expect(syncQueue.queueCount, 0);
      expect(syncQueue.hasPendingItems, isFalse);
      expect(syncQueue.isSchedulePendingSync('sch_xyz'), isFalse);
      expect(fakeRepo.created.length, 1);
      expect(fakeRepo.created.first.scheduleId, 'sch_xyz');
      expect(fakeRepo.created.first.material, 'Materi Algoritma Pemrograman');
    });

    test('3. Saat terjadi error koneksi di tengah sync, item tetap aman di antrean untuk retry berikutnya', () async {
      connectivity.reportOnline();
      fakeRepo.shouldThrow = true; // Simulasi error koneksi saat upload

      final journal = JournalModel(
        id: 'temp_003',
        scheduleId: 'sch_fail',
        date: DateTime(2026, 11, 23),
        teachingHour: 3,
        classId: 'cls_3',
        subjectId: 'sub_3',
        teacherId: 'tch_3',
        material: 'Materi Jaringan Komputer',
        status: 'pending',
      );

      await syncQueue.enqueueJournal(
        journal: journal,
        isUpdate: false,
      );

      expect(syncQueue.queueCount, 1);

      await syncQueue.processQueue(fakeRepo);

      // Data TIDAK boleh hilang, harus tetap ada di antrean
      expect(syncQueue.queueCount, 1);
      expect(syncQueue.queue.first.retryCount, greaterThan(0));
    });

    test('4. Mengubah ID non-UUID menjadi valid UUID dan menghapus flag isSyncPending saat dikirim ke repository', () async {
      connectivity.reportOffline();

      final offlineJournal = JournalModel(
        id: 'offline_1795491083443',
        scheduleId: 'sch_offline_uuid',
        date: DateTime(2026, 11, 24),
        teachingHour: 1,
        classId: 'cls_1',
        subjectId: 'sub_1',
        teacherId: 'tch_1',
        material: 'Materi Uji UUID',
        status: 'pending',
        isSyncPending: true,
      );

      await syncQueue.enqueueJournal(journal: offlineJournal, isUpdate: false);
      expect(syncQueue.queueCount, 1);

      connectivity.reportOnline();
      await syncQueue.processQueue(fakeRepo);

      expect(syncQueue.queueCount, 0);
      expect(fakeRepo.created.length, 1);
      final synced = fakeRepo.created.first;
      expect(synced.id.startsWith('offline_'), isFalse);
      expect(RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(synced.id), isTrue);
      expect(synced.isSyncPending, isFalse);
    });

    test('5. Otomatis sinkronisasi saat konektivitas berpindah dari offline ke online', () async {
      syncQueue.registerRepository(fakeRepo);
      connectivity.reportOffline();

      final offlineJournal = JournalModel(
        id: 'offline_auto_sync_test',
        scheduleId: 'sch_auto_sync',
        date: DateTime(2026, 11, 24),
        teachingHour: 2,
        classId: 'cls_2',
        subjectId: 'sub_2',
        teacherId: 'tch_2',
        material: 'Materi Auto Sync',
        status: 'pending',
        isSyncPending: true,
      );

      await syncQueue.enqueueJournal(journal: offlineJournal, isUpdate: false);
      expect(syncQueue.queueCount, 1);
      expect(fakeRepo.created.isEmpty, isTrue);

      // Simulasi koneksi kembali pulih (offline -> online)
      connectivity.reportOnline();
      await Future.delayed(const Duration(milliseconds: 100));

      // Harus otomatis tersinkron dan antrean menjadi bersih
      expect(syncQueue.queueCount, 0);
      expect(fakeRepo.created.length, 1);
      expect(fakeRepo.created.first.material, 'Materi Auto Sync');
    });

    test('6. Dapat mencoba ulang (retry) item yang berstatus failed', () async {
      syncQueue.registerRepository(fakeRepo);
      connectivity.reportOffline();

      final failJournal = JournalModel(
        id: 'fail_retry_test',
        scheduleId: 'sch_fail_retry',
        date: DateTime(2026, 11, 24),
        teachingHour: 1,
        classId: 'cls_3',
        subjectId: 'sub_3',
        teacherId: 'tch_3',
        material: 'Materi Gagal Awal',
        status: 'pending',
      );

      // Simulasikan database constraint error
      fakeRepo.shouldThrow = true;
      fakeRepo.errorToThrow = 'PGRST204: Foreign key violation';
      await syncQueue.enqueueJournal(journal: failJournal, isUpdate: false);
      expect(syncQueue.queueCount, 1);

      // Jalankan sync saat online dengan db error
      connectivity.reportOnline();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(syncQueue.queueCount, 1);
      expect(syncQueue.queue.first.status, 'failed');
      expect(syncQueue.queue.first.lastError, isNotNull);

      // Sembuhkan repository dan panggil retryItem
      fakeRepo.shouldThrow = false;
      fakeRepo.errorToThrow = null;
      await syncQueue.retryItem(syncQueue.queue.first.id, fakeRepo);

      // Antrean harus berhasil diproses dan bersih
      expect(syncQueue.queueCount, 0);
      expect(fakeRepo.created.length, 1);
    });
  });
}
