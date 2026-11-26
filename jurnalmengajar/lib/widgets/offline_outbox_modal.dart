import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/router/app_router.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/sync_queue_service.dart';
import '../models/journal_model.dart';
import '../providers/journal_provider.dart';
import 'app_dialog_actions.dart';

/// Modal bottom sheet untuk menampilkan rincian antrean offline (Kotak Keluar)
/// Memungkinkan guru melihat status antrean, mencoba ulang item yang gagal,
/// atau menghapus item yang sudah tidak diperlukan.
class OfflineOutboxModal extends StatelessWidget {
  const OfflineOutboxModal({super.key});

  static bool _isOpen = false;

  static Future<void> show([BuildContext? context]) {
    if (_isOpen) return Future.value();
    final navContext = AppRouter.rootNavigatorKey.currentContext ?? context;
    if (navContext == null) return Future.value();

    _isOpen = true;
    return showModalBottomSheet<void>(
      context: navContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const OfflineOutboxModal(),
    ).whenComplete(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final connectivity = ConnectivityService.instance;
    final syncQueue = SyncQueueService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([syncQueue, connectivity]),
      builder: (context, _) {
        final items = syncQueue.queue;
        final isOnline = connectivity.isOnline;
        final isSyncing = syncQueue.isSyncing;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Antrean Sinkronisasi',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              items.isEmpty
                                  ? 'Tidak ada antrean tertunda'
                                  : '${items.length} jurnal dalam antrean lokal',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12.sp,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          size: 20.sp,
                        ),
                        splashRadius: 20.r,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Content
                Flexible(
                  child: items.isEmpty
                      ? _buildEmptyState(context, isDark)
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, _) => SizedBox(height: 10.h),
                          itemBuilder: (ctx, index) {
                            final item = items[index];
                            return _buildQueueCard(context, item, isDark);
                          },
                        ),
                ),

                // Bottom Action
                if (items.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton.icon(
                        onPressed:
                            (isOnline &&
                                !isSyncing &&
                                syncQueue.registeredRepository != null)
                            ? () {
                                syncQueue.processQueue(
                                  syncQueue.registeredRepository!,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          elevation: 0,
                        ),
                        icon: isSyncing
                            ? SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isOnline
                                    ? Icons.sync_rounded
                                    : Icons.wifi_off_rounded,
                                size: 18.sp,
                              ),
                        label: Text(
                          isSyncing
                              ? 'Menyinkronkan...'
                              : (isOnline
                                    ? 'Sinkronkan Semua Sekarang'
                                    : 'Menunggu Koneksi Internet'),
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF10B981),
                size: 36,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Semua Data Bersih',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Seluruh jurnal yang Anda isi telah terunggah ke database sekolah.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.5.sp,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(
    BuildContext context,
    SyncQueueItem item,
    bool isDark,
  ) {
    final rawData = item.journalData;
    final material = rawData['material']?.toString().trim();
    final effectiveMaterial = (material != null && material.isNotEmpty)
        ? material
        : 'Jurnal Tanpa Materi Khusus';

    final rawDate = rawData['date']?.toString();
    final parsedDate = rawDate != null ? DateTime.tryParse(rawDate) : null;
    String dateStr;
    try {
      dateStr = parsedDate != null
          ? DateFormat('EEEE, d MMM yyyy', 'id_ID').format(parsedDate)
          : 'Tanggal tidak tercatat';
    } catch (_) {
      dateStr = parsedDate != null
          ? DateFormat('yyyy-MM-dd').format(parsedDate)
          : 'Tanggal tidak tercatat';
    }

    final teachingHour = rawData['teaching_hour']?.toString() ?? '-';
    final photoCount = item.imageFilePaths.length + item.base64Images.length;

    // Visual attributes per status
    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    if (item.status == 'syncing') {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFF2563EB).withValues(alpha: 0.1);
      statusLabel = 'Mengunggah...';
      statusIcon = Icons.sync_rounded;
    } else if (item.status == 'failed') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
      statusLabel = 'Gagal';
      statusIcon = Icons.error_outline_rounded;
    } else {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFD97706).withValues(alpha: 0.1);
      statusLabel = 'Pending';
      statusIcon = Icons.schedule_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: item.status == 'failed'
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  effectiveMaterial,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12.sp, color: statusColor),
                    SizedBox(width: 4.w),
                    Text(
                      statusLabel,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12.sp,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    dateStr,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.5.sp,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                '•',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              Text(
                'Jam ke-$teachingHour',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11.5.sp,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              if (photoCount > 0) ...[
                Text(
                  '•',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_outlined,
                      size: 12.sp,
                      color: const Color(0xFF2563EB),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$photoCount foto',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          if (item.lastError != null && item.lastError!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                'Catatan: ${item.lastError}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11.5.sp,
                  color: const Color(0xFFDC2626),
                  height: 1.3,
                ),
              ),
            ),
          ],

          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.status == 'failed') ...[
                IconButton(
                  tooltip: 'Coba Lagi',
                  onPressed: () {
                    SyncQueueService.instance.retryItem(item.id);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  iconSize: 18.sp,
                  color: const Color(0xFF2563EB),
                  padding: EdgeInsets.all(6.r),
                  constraints: const BoxConstraints(),
                  splashRadius: 18.r,
                ),
                SizedBox(width: 8.w),
              ],
              IconButton(
                tooltip: 'Edit Jurnal',
                onPressed: () => _editQueueItem(context, item),
                icon: const Icon(Icons.edit_outlined),
                iconSize: 18.sp,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                padding: EdgeInsets.all(6.r),
                constraints: const BoxConstraints(),
                splashRadius: 18.r,
              ),
              SizedBox(width: 4.w),
              IconButton(
                tooltip: 'Hapus Antrean',
                onPressed: () => _confirmDeleteItem(context, item.id),
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 18.sp,
                color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                padding: EdgeInsets.all(6.r),
                constraints: const BoxConstraints(),
                splashRadius: 18.r,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editQueueItem(BuildContext context, SyncQueueItem item) {
    final rawData = item.journalData;
    final scheduleId = rawData['schedule_id']?.toString() ?? '';
    final rawDate = rawData['date']?.toString();
    final journalId = rawData['id']?.toString() ?? '';

    String? dateStr;
    if (rawDate != null) {
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) {
        dateStr = DateFormat('yyyy-MM-dd').format(dt);
      }
    }

    try {
      final journal = JournalModel.fromJson(rawData);
      final jp = Provider.of<JournalProvider>(context, listen: false);
      jp.addOptimisticJournal(journal);
    } catch (_) {}

    Navigator.of(context).pop();

    final navContext = AppRouter.rootNavigatorKey.currentContext ?? context;
    final queryParams = <String, String>{
      'scheduleId': scheduleId,
    };
    if (dateStr != null) queryParams['date'] = dateStr;
    if (journalId.isNotEmpty) queryParams['journalId'] = journalId;

    final uri = Uri(
      path: '/guru/journal-form',
      queryParameters: queryParams,
    ).toString();
    navContext.push(uri);
  }

  void _confirmDeleteItem(BuildContext context, String itemId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        title: Text(
          'Hapus dari Antrean?',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        content: Text(
          'Data jurnal ini belum tersinkronkan ke server. Jika dihapus, catatan tidak akan terunggah ke database sekolah.',
          style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          AppDialogActions(
            cancelText: 'Batal',
            confirmText: 'Hapus',
            isDestructive: true,
            onCancel: () => Navigator.of(ctx).pop(),
            onConfirm: () async {
              Navigator.of(ctx).pop();
              await SyncQueueService.instance.removeQueueItem(itemId);
            },
          ),
        ],
      ),
    );
  }
}
