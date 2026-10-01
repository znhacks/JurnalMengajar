import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../models/holiday_model.dart';
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
    final schoolId =
        authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';
    Provider.of<HolidayProvider>(context, listen: false).loadHolidays(schoolId);
  }

  static const List<String> _holidayCategories = [
    'Libur Hari Besar',
    'Libur Umum',
    'Cuti Bersama',
    'Libur Semester Ganjil',
    'Libur Semester Genap',
    'Libur Awal Ramadhan',
    'Libur Hari Raya Idul Fitri',
    'Libur Khusus Sekolah',
    'Lainnya',
  ];

  Color _getCategoryColor(String category, bool isDark) {
    final lower = category.toLowerCase();
    if (lower.contains('hari besar')) {
      return isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA);
    } else if (lower.contains('cuti bersama')) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    } else if (lower.contains('semester')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    } else if (lower.contains('ramadhan') || lower.contains('fitri')) {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    } else if (lower.contains('khusus')) {
      return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    } else {
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    }
  }

  void _showHolidayDialog({HolidayModel? holiday}) {
    final isEdit = holiday != null;
    final titleController = TextEditingController(text: holiday?.title ?? '');
    
    final initialCat = holiday?.category ?? holiday?.description ?? 'Libur Hari Besar';
    final isPredefined = _holidayCategories.contains(initialCat);
    String selectedCategory = isPredefined ? initialCat : 'Lainnya';
    final customCategoryController = TextEditingController(
      text: !isPredefined && initialCat.isNotEmpty ? initialCat : '',
    );

    DateTime startDate = holiday?.startDate ?? DateTime.now();
    DateTime endDate = holiday?.endDate ?? DateTime.now();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final startFormatted = DateFormat(
            'dd MMM yyyy',
            'id_ID',
          ).format(startDate);
          final endFormatted = DateFormat(
            'dd MMM yyyy',
            'id_ID',
          ).format(endDate);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_calendar_rounded : Icons.event_busy_rounded,
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Hari Libur' : 'Tambah Hari Libur',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
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
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Kategori Libur *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: _holidayCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: isSubmitting
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedCategory = val;
                              });
                            }
                          },
                  ),
                  if (selectedCategory == 'Lainnya') ...[
                    SizedBox(height: 12.h),
                    TextField(
                      controller: customCategoryController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Nama Kategori Lainnya *',
                        hintText: 'Misal: Libur Khusus Pondok / Ujian',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ],
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

                        final chosenCategory = selectedCategory == 'Lainnya'
                            ? (customCategoryController.text.trim().isNotEmpty
                                ? customCategoryController.text.trim()
                                : 'Libur Lainnya')
                            : selectedCategory;

                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final holidayProvider = Provider.of<HolidayProvider>(
                          context,
                          listen: false,
                        );
                        final schoolId =
                            authProvider.activeSchoolId ??
                            'a1111111-1111-1111-1111-111111111111';

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogCtx);
                        setDialogState(() => isSubmitting = true);

                        final success = isEdit
                            ? await holidayProvider.updateHoliday(
                                holidayId: holiday.id,
                                schoolId: schoolId,
                                title: title,
                                startDate: startDate,
                                endDate: endDate,
                                oldStartDate: holiday.startDate,
                                oldEndDate: holiday.endDate,
                                category: chosenCategory,
                                description: chosenCategory,
                              )
                            : await holidayProvider.addHoliday(
                                schoolId: schoolId,
                                title: title,
                                startDate: startDate,
                                endDate: endDate,
                                category: chosenCategory,
                                description: chosenCategory,
                                createdBy: authProvider.currentUser?.id,
                              );

                        if (mounted) {
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Hari libur berhasil diperbarui!'
                                      : 'Hari libur berhasil ditambahkan!',
                                ),
                              ),
                            );
                            navigator.pop();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  holidayProvider.errorMessage ??
                                      (isEdit
                                          ? 'Gagal memperbarui hari libur.'
                                          : 'Gagal menambahkan hari libur.'),
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
                    : const Text('Simpan'),
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
        title: const Text('Kelola Hari Libur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_off_rounded),
            tooltip: 'Kelola Cuti Guru',
            onPressed: () => context.push('/admin/teacher-leaves'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHolidays,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/holidays'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHolidayDialog(),
        backgroundColor: const Color(0xFFDC2626),
        child: const Icon(Icons.add_rounded, color: Colors.white),
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
                  final startStr = DateFormat(
                    'dd MMM yyyy',
                    'id_ID',
                  ).format(item.startDate);
                  final endStr = DateFormat(
                    'dd MMM yyyy',
                    'id_ID',
                  ).format(item.endDate);
                  final dateRangeLabel = startStr == endStr
                      ? startStr
                      : '$startStr - $endStr';
                  final itemCategory = item.category?.isNotEmpty == true
                      ? item.category!
                      : (item.description?.isNotEmpty == true
                          ? item.description!
                          : 'Libur Hari Besar');

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
                        child: Icon(
                          Icons.event_busy_rounded,
                          color: isDark
                              ? const Color(0xFFF87171)
                              : const Color(0xFFDC2626),
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
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                dateRangeLabel,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(
                                itemCategory,
                                isDark,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: _getCategoryColor(
                                  itemCategory,
                                  isDark,
                                ).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              itemCategory,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: _getCategoryColor(itemCategory, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF2563EB),
                            ),
                            tooltip: 'Edit Hari Libur',
                            onPressed: () => _showHolidayDialog(holiday: item),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Hapus Hari Libur',
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final schoolId =
                                  authProvider.activeSchoolId ??
                                  'a1111111-1111-1111-1111-111111111111';

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
                                      child: const Text(
                                        'Hapus',
                                        style: TextStyle(color: Colors.red),
                                      ),
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
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
