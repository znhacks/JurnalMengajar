import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/teacher_leave_provider.dart';
import '../../models/teacher_leave_model.dart';
import '../../models/teacher_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';

class AdminTeacherLeavesScreen extends StatefulWidget {
  const AdminTeacherLeavesScreen({super.key});

  @override
  State<AdminTeacherLeavesScreen> createState() => _AdminTeacherLeavesScreenState();
}

class _AdminTeacherLeavesScreenState extends State<AdminTeacherLeavesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _leaveReasons = [
    'Cuti Tahunan',
    'Cuti Sakit',
    'Cuti Melahirkan',
    'Cuti Alasan Penting',
    'Cuti Studi / Pelatihan',
    'Dinas Luar',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';
    Provider.of<TeacherLeaveProvider>(context, listen: false).loadLeaves(schoolId);
    Provider.of<MasterDataProvider>(context, listen: false).loadAllData(schoolId);
    Provider.of<ScheduleProvider>(context, listen: false).loadAllSchedules(schoolId);
  }

  Color _getReasonColor(String reason, bool isDark) {
    final lower = reason.toLowerCase();
    if (lower.contains('sakit')) {
      return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    } else if (lower.contains('melahirkan')) {
      return isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
    } else if (lower.contains('tahunan')) {
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    } else if (lower.contains('dinas')) {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    } else if (lower.contains('penting')) {
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    } else {
      return isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);
    }
  }

  void _showLeaveDialog({TeacherLeaveModel? leave}) {
    final isEdit = leave != null;
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final teachers = masterProvider.teachers;
    if (teachers.isEmpty) {
      AppHelper.showSnackBar(
        context,
        'Belum ada data guru terdaftar di sekolah ini.',
        isError: true,
      );
      return;
    }

    String? selectedTeacherId = leave?.teacherId ?? (teachers.isNotEmpty ? teachers.first.id : null);
    DateTime startDate = leave?.startDate ?? DateTime.now();
    DateTime endDate = leave?.endDate ?? DateTime.now();

    String initialReason = leave?.reason ?? _leaveReasons.first;
    final isPredefinedReason = _leaveReasons.contains(initialReason);
    String selectedReason = isPredefinedReason ? initialReason : 'Lainnya';
    final customReasonController = TextEditingController(
      text: !isPredefinedReason && initialReason.isNotEmpty ? initialReason : '',
    );

    // Map: scheduleId -> substituteTeacherId
    final Map<String, String> substituteAssignments = {};
    if (leave != null) {
      for (final sub in leave.substitutes) {
        substituteAssignments[sub.scheduleId] = sub.substituteTeacherId;
      }
    }

    String? bulkSubstituteTeacherId;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          final startFormatted = DateFormat('dd MMM yyyy', 'id_ID').format(startDate);
          final endFormatted = DateFormat('dd MMM yyyy', 'id_ID').format(endDate);

          // Filter schedules for the selected teacher within startDate and endDate
          final startDay = DateTime(startDate.year, startDate.month, startDate.day);
          final endDay = DateTime(endDate.year, endDate.month, endDate.day);

          final teacherSchedules = scheduleProvider.schedules.where((s) {
            if (s.teacherId != selectedTeacherId) return false;
            final sDay = DateTime(s.date.year, s.date.month, s.date.day);
            return (sDay.isAfter(startDay) || sDay.isAtSameMomentAs(startDay)) &&
                   (sDay.isBefore(endDay) || sDay.isAtSameMomentAs(endDay));
          }).toList();

          // Sort schedules chronologically
          teacherSchedules.sort((a, b) {
            final dateComp = a.date.compareTo(b.date);
            if (dateComp != 0) return dateComp;
            return a.teachingHour.compareTo(b.teachingHour);
          });

          // Teachers available as substitute (exclude the teacher on leave)
          final substituteCandidates = teachers.where((t) => t.id != selectedTeacherId).toList();

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
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_calendar_rounded : Icons.person_off_rounded,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Cuti & Guru Pengganti' : 'Tambah Cuti Guru',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Pilih Guru
                    Text(
                      'Pilih Guru yang Mengajukan Cuti *',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTeacherId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                      items: teachers.map((t) {
                        return DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.name + (t.nip != null && t.nip!.isNotEmpty ? ' (${t.nip})' : ''),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedTeacherId = val;
                                  substituteAssignments.clear();
                                  bulkSubstituteTeacherId = null;
                                });
                              }
                            },
                    ),
                    SizedBox(height: 14.h),

                    // 2. Rentang Tanggal Cuti
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
                                      lastDate: DateTime(2035),
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
                                      lastDate: DateTime(2035),
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

                    // 3. Alasan / Jenis Cuti
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Alasan / Jenis Cuti *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      items: _leaveReasons.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        );
                      }).toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedReason = val;
                                });
                              }
                            },
                    ),
                    if (selectedReason == 'Lainnya') ...[
                      SizedBox(height: 12.h),
                      TextField(
                        controller: customReasonController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Keterangan Alasan Lainnya *',
                          hintText: 'Misal: Keperluan keluarga mendesak',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 18.h),

                    // 4. Jadwal Mengajar & Pemilihan Guru Pengganti
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 18.w,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF2563EB),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Jadwal Mengajar Selama Cuti (${teacherSchedules.length} Sesi)',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Pilih guru pengganti untuk menggantikan seluruh jadwal mengajar selama masa cuti.',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 10.h),

                          if (teacherSchedules.isEmpty) ...[
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF059669),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Guru ini tidak memiliki jadwal mengajar pada rentang tanggal ini. Cuti tetap dapat disimpan tanpa guru pengganti.',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: isDark
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // 1 Tabel/Kotak yang langsung mengganti semua jadwal
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF475569)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total Jadwal Terdampak',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                                              : const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          '${teacherSchedules.length} Sesi Jam Pelajaran',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF60A5FA)
                                                : const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Pilih Guru Pengganti (Menggantikan Semua Jadwal) *',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  DropdownButtonFormField<String>(
                                    initialValue: bulkSubstituteTeacherId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      prefixIcon: const Icon(Icons.swap_horiz_rounded),
                                      hintText: 'Pilih guru pengganti...',
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          '- Tanpa Guru Pengganti -',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      ...substituteCandidates.map((t) {
                                        return DropdownMenuItem<String>(
                                          value: t.id,
                                          child: Text(
                                            t.name + (t.nip != null && t.nip!.isNotEmpty ? ' (${t.nip})' : ''),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: isSubmitting
                                        ? null
                                        : (val) {
                                            setDialogState(() {
                                              bulkSubstituteTeacherId = val;
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
                        if (selectedTeacherId == null || selectedTeacherId!.isEmpty) {
                          AppHelper.showSnackBar(context, 'Pilih guru yang cuti', isError: true);
                          return;
                        }

                        final finalReason = selectedReason == 'Lainnya'
                            ? (customReasonController.text.trim().isNotEmpty
                                ? customReasonController.text.trim()
                                : 'Cuti Lainnya')
                            : selectedReason;

                        final leaveProvider = Provider.of<TeacherLeaveProvider>(context, listen: false);
                        final schoolId = authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';

                        setDialogState(() => isSubmitting = true);

                        // Build substitute items for all teacherSchedules using bulkSubstituteTeacherId
                        final List<LeaveSubstituteItem> substituteList = [];
                        if (bulkSubstituteTeacherId != null && bulkSubstituteTeacherId!.isNotEmpty) {
                          final subTeacher = teachers.firstWhere(
                            (t) => t.id == bulkSubstituteTeacherId,
                            orElse: () => TeacherModel(
                              id: '',
                              name: 'Guru Pengganti',
                              position: '',
                              address: '',
                              phoneNumber: '',
                              email: '',
                            ),
                          );
                          for (final s in teacherSchedules) {
                            substituteList.add(
                              LeaveSubstituteItem(
                                scheduleId: s.id,
                                date: s.date,
                                teachingHour: s.teachingHour,
                                classId: s.classId,
                                subjectId: s.subjectId,
                                substituteTeacherId: bulkSubstituteTeacherId!,
                                substituteTeacherName: subTeacher.name,
                              ),
                            );
                          }
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogCtx);

                        final ok = await leaveProvider.addLeave(
                          schoolId: schoolId,
                          teacherId: selectedTeacherId!,
                          startDate: startDate,
                          endDate: endDate,
                          reason: finalReason,
                          substitutes: substituteList,
                          createdBy: authProvider.currentUser?.id,
                        );

                        if (mounted) {
                          if (ok) {
                            // Reload schedules in schedule provider so substitute links take effect
                            scheduleProvider.loadAllSchedules(schoolId);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Data cuti dan guru pengganti berhasil disimpan!'),
                              ),
                            );
                            navigator.pop();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(leaveProvider.errorMessage ?? 'Gagal menyimpan data cuti.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
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

  void _showDetailDialog(TeacherLeaveModel leave, TeacherModel? teacher) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final startStr = DateFormat('dd MMM yyyy', 'id_ID').format(leave.startDate);
    final endStr = DateFormat('dd MMM yyyy', 'id_ID').format(leave.endDate);
    final dateRangeLabel = startStr == endStr ? startStr : '$startStr s/d $endStr';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                    : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: const Icon(
                Icons.assignment_ind_rounded,
                color: Color(0xFF2563EB),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Detail Cuti & Guru Pengganti',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500.w,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Guru
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher?.name ?? 'Guru Tidak Ditemukan',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
                      if (teacher?.nip != null && teacher!.nip!.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'NIP: ${teacher.nip}',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                        ),
                      ],
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            dateRangeLabel,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Alasan: ${leave.reason ?? "-"}',
                        style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                Text(
                  'Penugasan Guru Pengganti (${leave.substitutes.length} Sesi)',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),

                if (leave.substitutes.isEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Center(
                      child: Text(
                        'Tidak ada jadwal yang ditugaskan kepada guru pengganti.',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 6.w),
                            Text(
                              'Guru Pengganti: ',
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                            ),
                            Expanded(
                              child: Text(
                                leave.substitutes.first.substituteTeacherName ?? 'Guru Pengganti',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 14, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                            SizedBox(width: 6.w),
                            Text(
                              'Menggantikan ${leave.substitutes.length} Sesi Jam Mengajar',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<TeacherLeaveProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final teachers = masterProvider.teachers;
    final allLeaves = leaveProvider.leaves;

    // Filter leaves by search
    final filteredLeaves = allLeaves.where((l) {
      if (_searchQuery.isEmpty) return true;
      final t = teachers.firstWhere(
        (teach) => teach.id == l.teacherId,
        orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
      );
      final matchTeacher = t.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchReason = (l.reason ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      return matchTeacher || matchReason;
    }).toList();

    // Summary calculations
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeLeavesCount = allLeaves.where((l) {
      final s = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
      final e = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
      return (today.isAfter(s) || today.isAtSameMomentAs(s)) &&
             (today.isBefore(e) || today.isAtSameMomentAs(e));
    }).length;

    int totalSubstitutedSessions = 0;
    for (final l in allLeaves) {
      totalSubstitutedSessions += l.substitutes.length;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Cuti Guru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/teacher-leaves'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLeaveDialog(),
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Overview Stats
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Total Cuti',
                      count: allLeaves.length.toString(),
                      icon: Icons.list_alt_rounded,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Cuti Hari Ini',
                      count: activeLeavesCount.toString(),
                      icon: Icons.person_off_rounded,
                      color: const Color(0xFFDC2626),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Sesi Digantikan',
                      count: totalSubstitutedSessions.toString(),
                      icon: Icons.swap_horiz_rounded,
                      color: const Color(0xFF059669),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari guru atau alasan cuti...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
              ),
            ),

            // Content List
            Expanded(
              child: leaveProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredLeaves.isEmpty
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
                              _searchQuery.isNotEmpty
                                  ? 'Tidak Ada Hasil yang Cocok'
                                  : 'Belum Ada Cuti Guru Ditambahkan',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Coba kata kunci pencarian yang lain.'
                                  : 'Catat cuti guru dan pilih guru pengganti untuk jadwal mengajarnya agar kegiatan belajar tetap terkelola.',
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
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 80.h),
                      itemCount: filteredLeaves.length,
                      itemBuilder: (context, index) {
                        final item = filteredLeaves[index];
                        final teacher = teachers.firstWhere(
                          (t) => t.id == item.teacherId,
                          orElse: () => TeacherModel(
                            id: '',
                            name: 'Guru Tidak Dikenal',
                            position: '',
                            address: '',
                            phoneNumber: '',
                            email: '',
                          ),
                        );

                        final startStr = DateFormat('dd MMM yyyy', 'id_ID').format(item.startDate);
                        final endStr = DateFormat('dd MMM yyyy', 'id_ID').format(item.endDate);
                        final dateRangeLabel = startStr == endStr ? startStr : '$startStr - $endStr';
                        final durationDays = item.endDate.difference(item.startDate).inDays + 1;

                        final reason = item.reason ?? 'Cuti Tahunan';
                        final reasonColor = _getReasonColor(reason, isDark);

                        return Card(
                          margin: EdgeInsets.only(bottom: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: InkWell(
                            onTap: () => _showDetailDialog(item, teacher),
                            borderRadius: BorderRadius.circular(14.r),
                            child: Padding(
                              padding: EdgeInsets.all(14.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20.r,
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                                            : const Color(0xFFDBEAFE),
                                        child: Text(
                                          teacher.name.isNotEmpty
                                              ? teacher.name.substring(0, 1).toUpperCase()
                                              : 'G',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF60A5FA)
                                                : const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              teacher.name,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 11,
                                                  color: Theme.of(context).colorScheme.outline,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  '$dateRangeLabel ($durationDays hari)',
                                                  style: TextStyle(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? const Color(0xFF60A5FA)
                                                        : const Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        tooltip: 'Hapus Cuti',
                                        onPressed: () async {
                                          final schoolId = authProvider.activeSchoolId ?? 'a1111111-1111-1111-1111-111111111111';
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Hapus Cuti Guru?'),
                                              content: Text(
                                                'Menghapus cuti "${teacher.name}" akan membatalkan penugasan guru pengganti dan mengembalikan jadwal semula.',
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

                                          if (confirm == true && context.mounted) {
                                            final messenger = ScaffoldMessenger.of(context);
                                            final ok = await leaveProvider.deleteLeave(
                                              item.id,
                                              schoolId,
                                              item.substitutes,
                                            );
                                            if (ok && context.mounted) {
                                              Provider.of<ScheduleProvider>(context, listen: false).loadAllSchedules(schoolId);
                                              messenger.showSnackBar(
                                                const SnackBar(content: Text('Data cuti berhasil dihapus')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: reasonColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6.r),
                                          border: Border.all(
                                            color: reasonColor.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: reasonColor,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                                              : const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6.r),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF047857)
                                                : const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.swap_horiz_rounded,
                                              size: 12,
                                              color: isDark
                                                  ? const Color(0xFF34D399)
                                                  : const Color(0xFF059669),
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              '${item.substitutes.length} Sesi Digantikan',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _showDetailDialog(item, teacher),
                                        icon: const Icon(Icons.info_outline, size: 14),
                                        label: const Text('Detail', style: TextStyle(fontSize: 11)),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.w, color: color),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            count,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
