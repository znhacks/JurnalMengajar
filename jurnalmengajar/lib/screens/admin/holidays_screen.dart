import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';

class AdminHolidaysScreen extends StatefulWidget {
  const AdminHolidaysScreen({super.key});

  @override
  State<AdminHolidaysScreen> createState() => _AdminHolidaysScreenState();
}

class _AdminHolidaysScreenState extends State<AdminHolidaysScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHolidays();
    });
  }

  void _loadHolidays() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';
    Provider.of<HolidayProvider>(context, listen: false).loadHolidays(schoolId);
  }

  void _showAddHolidayDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final startFormatted = DateFormat('dd MMM yyyy', 'id_ID').format(startDate);
          final endFormatted = DateFormat('dd MMM yyyy', 'id_ID').format(endDate);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
                SizedBox(width: 12.w),
                const Expanded(
                  child: Text(
                    'Tambah Hari Libur / Cuti',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Judul / Nama Libur *',
                      hintText: 'Contoh: Hari Kemerdekaan / Cuti Bersama',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: startDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      startDate = picked;
                                      if (endDate.isBefore(startDate)) {
                                        endDate = startDate;
                                      }
                                    });
                                  }
                                },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Tanggal Mulai',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              startFormatted,
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: InkWell(
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      endDate = picked;
                                    });
                                  }
                                },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Tanggal Selesai',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              endFormatted,
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: descController,
                    enabled: !isSubmitting,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Keterangan (Opsional)',
                      hintText: 'Misal: Seluruh kegiatan KBM ditiadakan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF78350F).withValues(alpha: 0.35)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF92400E)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Jurnal guru yang sudah terisi di tanggal libur ini akan di-soft-delete otomatis.',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFFED7AA)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          AppHelper.showSnackBar(
                            context,
                            'Judul libur tidak boleh kosong',
                            isError: true,
                          );
                          return;
                        }

                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final holidayProvider = Provider.of<HolidayProvider>(context, listen: false);
                        final schoolId = authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogCtx);
                        setDialogState(() => isSubmitting = true);

                        final success = await holidayProvider.addHoliday(
                          schoolId: schoolId,
                          title: title,
                          startDate: startDate,
                          endDate: endDate,
                          description: descController.text.trim(),
                          createdBy: authProvider.currentUser?.id,
                        );

                        if (mounted) {
                          if (success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Hari libur berhasil ditambahkan!'),
                              ),
                            );
                            navigator.pop();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  holidayProvider.errorMessage ?? 'Gagal menambahkan hari libur.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: isSubmitting
                    ? SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Simpan Libur'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holidayProvider = context.watch<HolidayProvider>();
    final authProvider = context.watch<AuthProvider>();
    final holidays = holidayProvider.holidays;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Hari Libur / Cuti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHolidays,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/holidays'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHolidayDialog,
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah Libur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: holidayProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : holidays.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 64.w,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Belum Ada Hari Libur Ditambahkan',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Tambahkan libur/cuti sekolah agar pengisian jurnal guru pada hari tersebut ditiadakan secara otomatis.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: holidays.length,
                    itemBuilder: (context, index) {
                      final item = holidays[index];
                      final startStr = DateFormat('dd MMM yyyy', 'id_ID').format(item.startDate);
                      final endStr = DateFormat('dd MMM yyyy', 'id_ID').format(item.endDate);
                      final dateRangeLabel = startStr == endStr ? startStr : '$startStr - $endStr';

                      return Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(14.w),
                          leading: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: const Icon(
                              Icons.event_busy_rounded,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Theme.of(context).colorScheme.outline),
                                  SizedBox(width: 4.w),
                                  Text(
                                    dateRangeLabel,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.description != null && item.description!.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final schoolId = authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Hapus Hari Libur?'),
                                  content: Text(
                                    'Menghapus hari libur "${item.title}" akan mengaktifkan kembali tanggal ini dan merestore jurnal yang di-soft-delete.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                final ok = await holidayProvider.deleteHoliday(
                                  item.id,
                                  schoolId,
                                  startDate: item.startDate,
                                  endDate: item.endDate,
                                );
                                if (ok && mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Hari libur berhasil dihapus'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
