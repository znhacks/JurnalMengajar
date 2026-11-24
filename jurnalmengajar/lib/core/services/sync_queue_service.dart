import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/journal_model.dart';
import '../../repositories/journal_repository.dart';
import '../../repositories/supabase_journal_repository.dart';
import '../utils/helper.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

/// Model item antrean mutasi offline
class SyncQueueItem {
  final String id;
  final String action; // 'CREATE_JOURNAL' | 'UPDATE_JOURNAL'
  final Map<String, dynamic> journalData;
  final List<String> base64Images;
  final List<String> imageNames;
  final DateTime createdAt;
  int retryCount;
  String status; // 'pending' | 'syncing' | 'failed'

  SyncQueueItem({
    required this.id,
    required this.action,
    required this.journalData,
    this.base64Images = const [],
    this.imageNames = const [],
    required this.createdAt,
    this.retryCount = 0,
    this.status = 'pending',
  });

  String get scheduleId =>
      journalData['schedule_id']?.toString() ??
      journalData['scheduleId']?.toString() ??
      '';

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String? ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      action: json['action'] as String? ?? 'CREATE_JOURNAL',
      journalData: Map<String, dynamic>.from(json['journal_data'] as Map? ?? {}),
      base64Images: (json['base64_images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      imageNames: (json['image_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      retryCount: json['retry_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'journal_data': journalData,
      'base64_images': base64Images,
      'image_names': imageNames,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'status': status,
    };
  }
}

/// Service pengelola antrean mutasi offline (Local Outbox Pattern)
/// yang otomatis mengirimkan data saat koneksi internet kembali aktif.
class SyncQueueService with ChangeNotifier {
  static final SyncQueueService instance = SyncQueueService._internal();
  factory SyncQueueService() => instance;

  SyncQueueService._internal() {
    _initQueue();
    ConnectivityService.instance.addListener(_handleConnectivityChange);
  }

  static const String _kQueueCacheKey = 'offline_sync_queue';
  final List<SyncQueueItem> _queue = [];
  bool _isInitialized = false;
  bool _isSyncing = false;
  JournalRepository? _registeredRepository;

  List<SyncQueueItem> get queue => List.unmodifiable(_queue);
  int get queueCount => _queue.length;
  bool get isSyncing => _isSyncing;
  bool get hasPendingItems => _queue.isNotEmpty;
  JournalRepository? get registeredRepository => _registeredRepository;

  /// Daftarkan JournalRepository aktif untuk proses sinkronisasi otomatis
  void registerRepository(JournalRepository repo) {
    _registeredRepository = repo;
    if (_isInitialized) {
      if (ConnectivityService.instance.isOnline && hasPendingItems && !_isSyncing) {
        processQueue(repo);
      }
    } else {
      _initQueue().then((_) {
        if (ConnectivityService.instance.isOnline && hasPendingItems && !_isSyncing) {
          processQueue(repo);
        }
      });
    }
  }

  Future<void> _initQueue() async {
    if (_isInitialized) return;
    try {
      final cachedList = await CacheService().loadList(_kQueueCacheKey);
      if (cachedList != null) {
        _queue.clear();
        for (final item in cachedList) {
          _queue.add(SyncQueueItem.fromJson(item));
        }
      }
      _isInitialized = true;
      notifyListeners();

      if (ConnectivityService.instance.isOnline && hasPendingItems && !_isSyncing && _registeredRepository != null) {
        unawaited(processQueue(_registeredRepository!));
      }
    } catch (e) {
      debugPrint('[SyncQueueService] Error loading queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final data = _queue.map((item) => item.toJson()).toList();
      await CacheService().save(_kQueueCacheKey, data);
    } catch (e) {
      debugPrint('[SyncQueueService] Error persisting queue: $e');
    }
  }

  void _handleConnectivityChange() {
    if (ConnectivityService.instance.isOnline && hasPendingItems && !_isSyncing) {
      if (_registeredRepository != null) {
        processQueue(_registeredRepository!);
      }
    }
  }

  /// Masukkan jurnal ke dalam antrean offline
  Future<SyncQueueItem> enqueueJournal({
    required JournalModel journal,
    required bool isUpdate,
    List<Uint8List>? imageBytesList,
    List<String>? imageNamesList,
  }) async {
    await _initQueue();

    final List<String> base64Images = [];
    if (imageBytesList != null && imageBytesList.isNotEmpty) {
      for (final bytes in imageBytesList) {
        base64Images.add(base64Encode(bytes));
      }
    }

    final item = SyncQueueItem(
      id: 'sync_${DateTime.now().millisecondsSinceEpoch}_${journal.scheduleId}',
      action: isUpdate ? 'UPDATE_JOURNAL' : 'CREATE_JOURNAL',
      journalData: journal.toJson(),
      base64Images: base64Images,
      imageNames: imageNamesList ?? [],
      createdAt: DateTime.now(),
      status: 'pending',
    );

    // Replace previous queued mutation for the same schedule.
    _queue.removeWhere((q) => q.scheduleId == journal.scheduleId);
    _queue.add(item);
    await _persistQueue();
    notifyListeners();

    if (ConnectivityService.instance.isOnline && _registeredRepository != null) {
      unawaited(processQueue(_registeredRepository!));
    }

    return item;
  }

  /// Mengecek apakah suatu jadwal memiliki jurnal yang sedang mengantre di offline
  bool isSchedulePendingSync(String scheduleId) {
    return _queue.any((q) => q.scheduleId == scheduleId && q.status != 'failed');
  }

  /// Proses seluruh antrean yang pending ke Supabase
  Future<void> processQueue(
    JournalRepository repo, {
    void Function(String scheduleId, String journalId)? onJournalSynced,
  }) async {
    if (_isSyncing || !ConnectivityService.instance.isOnline || _queue.isEmpty) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    debugPrint('[SyncQueueService] Starting sync for ${_queue.length} pending items...');

    final List<SyncQueueItem> itemsToProcess = List.from(_queue);

    for (final item in itemsToProcess) {
      if (!ConnectivityService.instance.isOnline) {
        debugPrint('[SyncQueueService] Connection lost during sync. Pausing queue.');
        break;
      }

      item.status = 'syncing';
      notifyListeners();

      try {
        final rawMap = Map<String, dynamic>.from(item.journalData);
        rawMap.remove('is_sync_pending');
        final currentId = rawMap['id']?.toString() ?? '';
        final validId = AppHelper.isValidUuid(currentId) ? currentId : const Uuid().v4();
        rawMap['id'] = validId;

        final journalModel = JournalModel.fromJson(rawMap).copyWith(
          isSyncPending: false,
        );

        // Upload lampiran gambar jika ada
        String? finalAttachmentUrl = journalModel.attachmentUrl;
        if (item.base64Images.isNotEmpty && repo is SupabaseJournalRepository) {
          final uploadedUrls = <String>[];
          for (int i = 0; i < item.base64Images.length && i < 3; i++) {
            try {
              final bytes = base64Decode(item.base64Images[i]);
              final name = i < item.imageNames.length
                  ? item.imageNames[i]
                  : 'lampiran_${i + 1}.jpg';
              final url = await repo.uploadAttachment(
                bytes,
                name,
                journalModel.id.isNotEmpty
                    ? journalModel.id
                    : 'temp_${DateTime.now().millisecondsSinceEpoch}',
                suffix: '_${i + 1}',
              );
              uploadedUrls.add(url);
            } catch (imgErr) {
              debugPrint('[SyncQueueService] Error uploading queued image: $imgErr');
            }
          }
          if (uploadedUrls.isNotEmpty) {
            finalAttachmentUrl = uploadedUrls.join(',');
          }
        }

        final readyModel = journalModel.copyWith(
          attachmentUrl: finalAttachmentUrl,
          isSyncPending: false,
        );

        if (item.action == 'UPDATE_JOURNAL' && readyModel.id.isNotEmpty) {
          try {
            await repo.update(readyModel);
          } catch (_) {
            await repo.create(readyModel);
          }
        } else {
          await repo.create(readyModel);
        }

        _queue.removeWhere((q) => q.id == item.id);
        await _persistQueue();
        debugPrint('[SyncQueueService] Successfully synced journal for schedule ${item.scheduleId}');

        if (onJournalSynced != null) {
          onJournalSynced(item.scheduleId, readyModel.id);
        }
      } catch (e) {
        debugPrint('[SyncQueueService] Error syncing item ${item.id}: $e');
        item.retryCount++;
        final errStr = e.toString().toLowerCase();
        final isNetworkIssue = errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('timeout') ||
            errStr.contains('network') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('handshake');

        if (isNetworkIssue) {
          item.status = 'pending';
          ConnectivityService.instance.reportOffline();
          break; // Hentikan loop jika koneksi terputus
        } else {
          // Error database (misal foreign key dihapus)
          item.status = 'failed';
        }
      }
    }

    _isSyncing = false;
    await _persistQueue();
    notifyListeners();
  }

  /// Menghapus antrean tertentu secara manual
  Future<void> removeQueueItem(String itemId) async {
    _queue.removeWhere((q) => q.id == itemId);
    await _persistQueue();
    notifyListeners();
  }

  /// Bersihkan seluruh antrean (berguna saat test teardown atau logout)
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();
    notifyListeners();
  }
}
