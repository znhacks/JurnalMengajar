import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/period_model.dart';
import '../../../models/class_model.dart';
import '../../../models/student_model.dart';
import '../../../providers/master_data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helper.dart';
import '../../../widgets/state_widgets.dart';
import '../../../widgets/admin_drawer.dart';

class StudentPromotionScreen extends StatefulWidget {
  final String? initialClassId;

  const StudentPromotionScreen({super.key, this.initialClassId});

  @override
  State<StudentPromotionScreen> createState() => _StudentPromotionScreenState();
}

class _StudentPromotionScreenState extends State<StudentPromotionScreen> {
  int _currentStep = 0; // 0: Sumber & Tujuan, 1: Pilih Siswa & Status, 2: Verifikasi & Konfirmasi

  // Sumber
  String? _sourcePeriodId;
  String? _sourceClassId;
  List<StudentModel> _sourceStudents = [];
  bool _isLoadingStudents = false;

  // Tujuan
  String? _targetPeriodId;
  String? _targetClassId;
  bool _isGraduationMode = false; // Mode kelulusan murni

  // Tanggal Efektif
  final DateTime _transferDate = DateTime.now();

  // Siswa terpilih & status
  final Set<String> _selectedStudentIds = {};
  final Map<String, String> _studentStatusMap = {}; // studentId -> 'naik', 'tidak_naik', 'lulus', 'pindah', 'tetap'
  final Map<String, String?> _studentTargetClassMap = {}; // studentId -> override classId
  final Map<String, String> _studentNoteMap = {}; // studentId -> note

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _studentsScrollController = ScrollController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultValues();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _studentsScrollController.dispose();
    super.dispose();
  }

  void _initDefaultValues() {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final periods = masterProvider.periods;
    final classes = masterProvider.classes;

    if (widget.initialClassId != null && widget.initialClassId!.isNotEmpty) {
      try {
        final cls = classes.firstWhere((c) => c.id == widget.initialClassId);
        _sourceClassId = cls.id;
        _sourcePeriodId = cls.periodId;
      } catch (_) {}
    }

    if (_sourcePeriodId == null && periods.isNotEmpty) {
      final active = masterProvider.activePeriod ?? periods.first;
      _sourcePeriodId = active.id;
    }

    if (_sourcePeriodId != null && _sourceClassId == null) {
      final availableClasses = classes.where((c) => c.periodId == _sourcePeriodId).toList();
      if (availableClasses.isNotEmpty) {
        _sourceClassId = availableClasses.first.id;
      }
    }

    if (_sourceClassId != null) {
      _loadSourceStudents(_sourceClassId!);
    }
  }

  Future<void> _loadSourceStudents(String classId) async {
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      final students = await masterProvider.studentRepository.getAllByClass(classId);

      if (mounted) {
        setState(() {
          _sourceStudents = students;
          _selectedStudentIds.clear();
          _studentStatusMap.clear();
          _studentTargetClassMap.clear();
          _studentNoteMap.clear();

          // Default: seluruh siswa terpilih dan diset 'naik'
          for (final s in students) {
            _selectedStudentIds.add(s.id);
            _studentStatusMap[s.id] = _isGraduationMode ? 'lulus' : 'naik';
          }
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
        AppHelper.showSnackBar(context, 'Gagal memuat siswa: $e', isError: true);
      }
    }
  }

  void _toggleSelectAll(List<StudentModel> filtered) {
    setState(() {
      final allFilteredSelected = filtered.every((s) => _selectedStudentIds.contains(s.id));
      if (allFilteredSelected) {
        for (final s in filtered) {
          _selectedStudentIds.remove(s.id);
        }
      } else {
        for (final s in filtered) {
          _selectedStudentIds.add(s.id);
          _studentStatusMap.putIfAbsent(s.id, () => _isGraduationMode ? 'lulus' : 'naik');
        }
      }
    });
  }

  void _batchSetStatus(String status) {
    if (_selectedStudentIds.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih setidaknya satu siswa terlebih dahulu', isError: true);
      return;
    }

    setState(() {
      for (final id in _selectedStudentIds) {
        _studentStatusMap[id] = status;
      }
    });

    final statusLabel = _formatStatusLabel(status);
    AppHelper.showSnackBar(
      context,
      'Status ${_selectedStudentIds.length} siswa terpilih diset ke "$statusLabel"',
    );
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'naik':
        return 'Naik Kelas';
      case 'tidak_naik':
        return 'Tidak Naik Kelas';
      case 'lulus':
        return 'Lulus';
      case 'pindah':
        return 'Pindah Kelas';
      case 'tetap':
      default:
        return 'Tetap';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'naik':
        return const Color(0xFF10B981);
      case 'lulus':
        return const Color(0xFF8B5CF6);
      case 'tidak_naik':
        return const Color(0xFFF59E0B);
      case 'pindah':
        return const Color(0xFF06B6D4);
      case 'tetap':
      default:
        return const Color(0xFF64748B);
    }
  }

  bool _validateStep1() {
    if (_sourcePeriodId == null || _sourcePeriodId!.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih tahun ajaran asal.', isError: true);
      return false;
    }
    if (_sourceClassId == null || _sourceClassId!.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih kelas asal.', isError: true);
      return false;
    }
    if (!_isGraduationMode) {
      if (_targetPeriodId == null || _targetPeriodId!.isEmpty) {
        AppHelper.showSnackBar(context, 'Pilih tahun ajaran tujuan.', isError: true);
        return false;
      }
      if (_targetClassId == null || _targetClassId!.isEmpty) {
        AppHelper.showSnackBar(context, 'Pilih kelas tujuan utama.', isError: true);
        return false;
      }
    }
    return true;
  }

  bool _validateStep2() {
    if (_selectedStudentIds.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih minimal satu siswa untuk diproses.', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _handleProcessPromotions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8.w),
            const Text('Konfirmasi Proses'),
          ],
        ),
        content: Text(
          'Yakin ingin memproses ${_selectedStudentIds.length} data siswa ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proses'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

      final List<Map<String, dynamic>> items = [];
      for (final studentId in _selectedStudentIds) {
        final status = _studentStatusMap[studentId] ?? (_isGraduationMode ? 'lulus' : 'naik');
        final targetClassId = _studentTargetClassMap[studentId] ?? _targetClassId;
        final note = _studentNoteMap[studentId];

        items.add({
          'student_id': studentId,
          'status': status,
          if (targetClassId != null && targetClassId.isNotEmpty) 'target_class_id': targetClassId,
          if (note != null && note.isNotEmpty) 'note': note,
        });
      }

      final result = await masterProvider.processStudentPromotions(
        sourcePeriodId: _sourcePeriodId!,
        sourceClassId: _sourceClassId!,
        targetPeriodId: _isGraduationMode ? null : _targetPeriodId,
        targetClassId: _isGraduationMode ? null : _targetClassId,
        items: items,
        transferDate: _transferDate,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result['success'] == true) {
        final successMessage = result['message']?.toString() ??
            '${items.length} siswa berhasil diproses dan histori akademik telah diperbarui.';
        AppHelper.showSnackBar(context, successMessage);
        if (mounted) {
          setState(() {
            _selectedStudentIds.clear();
            _studentStatusMap.clear();
            _studentTargetClassMap.clear();
            _studentNoteMap.clear();
            _currentStep = 0;
          });
          if (_sourceClassId != null && _sourceClassId!.isNotEmpty) {
            await _loadSourceStudents(_sourceClassId!);
          }
        }
      } else {
        AppHelper.showSnackBar(
          context,
          result['message']?.toString() ?? 'Gagal memproses kenaikan kelas.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppHelper.showSnackBar(context, 'Terjadi kesalahan: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = Provider.of<MasterDataProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final periods = masterProvider.periods;
    final classes = masterProvider.classes;

    final sourceClasses = classes.where((c) => c.periodId == _sourcePeriodId).toList();
    final targetClasses = classes.where((c) => c.periodId == _targetPeriodId).toList();

    return Scaffold(
      drawer: const AdminDrawer(
        currentRoute: '/admin/master-data/student-promotions',
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Kenaikan & Mutasi Kelas',
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Panduan Alur',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Panduan Kenaikan Kelas'),
                  content: const Text(
                    '1. Pilih Tahun Ajaran dan Kelas Asal.\n'
                    '2. Pilih Tahun Ajaran dan Kelas Tujuan (atau centang Kelulusan).\n'
                    '3. Pilih siswa yang akan diproses dan tentukan statusnya (Naik, Tinggal, Lulus, Pindah).\n'
                    '4. Verifikasi ringkasan data sebelum melakukan konfirmasi.\n\n'
                    'Data siswa dan histori tahun ajaran lama tetap tersimpan dengan aman tanpa data yang hilang.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Mengerti'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: masterProvider.isLoading && masterProvider.classes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Step Progress Header
                _buildStepHeader(isDark),

                // Step Content
                Expanded(
                  child: _isSubmitting
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Memproses data kenaikan kelas secara aman...'),
                            ],
                          ),
                        )
                      : _buildStepBody(periods, sourceClasses, targetClasses, isDark),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: _buildBottomBar(isDark),
      ),
    );
  }

  Widget _buildStepHeader(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final steps = [
          {
            'title': isCompact ? 'Sumber' : 'Sumber & Tujuan',
            'icon': Icons.tune_rounded,
          },
          {
            'title': isCompact ? 'Pilih Siswa' : 'Pilih Siswa',
            'icon': Icons.checklist_rounded,
          },
          {
            'title': isCompact ? 'Verifikasi' : 'Verifikasi',
            'icon': Icons.verified_rounded,
          },
        ];

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10.w : 16.w,
            vertical: 10.h,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = _currentStep > index;
              final isCurrent = _currentStep == index;
              final color = isCurrent
                  ? AppTheme.primaryColor
                  : isCompleted
                      ? Colors.green
                      : Colors.grey;

              return Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: isCompact ? 12.r : 14.r,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(
                        isCompleted ? Icons.check : (steps[index]['icon'] as IconData),
                        size: isCompact ? 12.w : 14.w,
                        color: color,
                      ),
                    ),
                    SizedBox(width: isCompact ? 4.w : 8.w),
                    Flexible(
                      child: Text(
                        steps[index]['title'] as String,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: isCompact ? 11.sp : 12.sp,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.onSurface
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (index < steps.length - 1)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 2.w : 6.w,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: isCompact ? 14.w : 16.w,
                          color: Colors.grey[400],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildStepBody(
    List<PeriodModel> periods,
    List<ClassModel> sourceClasses,
    List<ClassModel> targetClasses,
    bool isDark,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep1SourceAndTarget(periods, sourceClasses, targetClasses, isDark);
      case 1:
        return _buildStep2SelectStudents(targetClasses, isDark);
      case 2:
      default:
        return _buildStep3Verification(periods, isDark);
    }
  }

  Widget _buildStep1SourceAndTarget(
    List<PeriodModel> periods,
    List<ClassModel> sourceClasses,
    List<ClassModel> targetClasses,
    bool isDark,
  ) {
    final selectedSourcePeriod = periods.where((p) => p.id == _sourcePeriodId).firstOrNull;
    final selectedSourceClass = sourceClasses.where((c) => c.id == _sourceClassId).firstOrNull;
    final selectedTargetPeriod = periods.where((p) => p.id == _targetPeriodId).firstOrNull;
    final selectedTargetClass = targetClasses.where((c) => c.id == _targetClassId).firstOrNull;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Visualisasi Alur
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alur Kenaikan & Perpindahan',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedSourcePeriod?.name ?? 'Pilih Asal',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            selectedSourceClass?.name ?? 'Kelas Asal',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _isGraduationMode
                                ? 'Status Akhir'
                                : (selectedTargetPeriod?.name ?? 'Pilih Tujuan'),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _isGraduationMode
                                ? 'Kelulusan Siswa'
                                : (selectedTargetClass?.name ?? 'Kelas Tujuan'),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // KARTU 1: KELAS ASAL (SUMBER)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.login_rounded, color: AppTheme.primaryColor, size: 20.w),
                      SizedBox(width: 8.w),
                      Text(
                        '1. Kelas & Periode Asal (Sumber)',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Dropdown Periode Asal
                  DropdownButtonFormField<String>(
                    initialValue: _sourcePeriodId,
                    decoration: InputDecoration(
                      labelText: 'Tahun Ajaran Asal',
                      prefixIcon: const Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: periods.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name}${p.isActive ? " (Aktif)" : ""}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sourcePeriodId = val;
                          _sourceClassId = null;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 12.h),

                  // Dropdown Kelas Asal
                  DropdownButtonFormField<String>(
                    initialValue: _sourceClassId,
                    decoration: InputDecoration(
                      labelText: 'Kelas Asal',
                      prefixIcon: const Icon(Icons.class_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: sourceClasses.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.studentCount} Siswa)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sourceClassId = val);
                        _loadSourceStudents(val);
                      }
                    },
                  ),

                  if (_sourceClassId != null) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey),
                        SizedBox(width: 6.w),
                        Text(
                          _isLoadingStudents
                              ? 'Memuat data siswa...'
                              : 'Total Siswa di Kelas Ini: ${_sourceStudents.length}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // KARTU 2: KELAS TUJUAN (TARGET)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 8.w),
                      Text(
                        '2. Kelas & Periode Tujuan (Target)',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Switch Kelulusan
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Proses Kelulusan (Tingkat Akhir)',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Siswa akan berstatus "Lulus" tanpa dipindahkan ke kelas lain.',
                      style: GoogleFonts.hankenGrotesk(fontSize: 11.sp, color: Colors.grey),
                    ),
                    value: _isGraduationMode,
                    activeThumbColor: const Color(0xFF8B5CF6),
                    onChanged: (val) {
                      setState(() {
                        _isGraduationMode = val;
                        for (final id in _selectedStudentIds) {
                          _studentStatusMap[id] = val ? 'lulus' : 'naik';
                        }
                      });
                    },
                  ),

                  if (!_isGraduationMode) ...[
                    SizedBox(height: 8.h),
                    // Dropdown Periode Tujuan
                    DropdownButtonFormField<String>(
                      initialValue: _targetPeriodId,
                      decoration: InputDecoration(
                        labelText: 'Tahun Ajaran Tujuan',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: periods.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name}${p.isActive ? " (Aktif)" : ""}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _targetPeriodId = val;
                            _targetClassId = null;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 12.h),

                    // Dropdown Kelas Tujuan
                    DropdownButtonFormField<String>(
                      initialValue: _targetClassId,
                      decoration: InputDecoration(
                        labelText: 'Kelas Tujuan Utama',
                        prefixIcon: const Icon(Icons.class_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: targetClasses.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name} (${c.studentCount} Siswa)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _targetClassId = val);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2SelectStudents(List<ClassModel> targetClasses, bool isDark) {
    final filtered = _sourceStudents.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = s.name.toLowerCase().contains(q);
      final nisMatch = s.nis?.toLowerCase().contains(q) ?? false;
      return nameMatch || nisMatch;
    }).toList();

    return Column(
      children: [
        // Action toolbar: Search & Mass Status Assignment
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari siswa di kelas asal...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12.w),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              SizedBox(height: 8.h),

              // Mass actions chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final isAllSelected = _selectedStudentIds.length == filtered.length && filtered.isNotEmpty;
                        return ActionChip(
                          avatar: Icon(
                            Icons.checklist_rounded,
                            size: 16,
                            color: isAllSelected
                                ? const Color(0xFF38BDF8)
                                : (isDark ? Colors.white70 : const Color(0xFF0284C7)),
                          ),
                          label: Text(
                            isAllSelected
                                ? 'Batal Pilih Semua'
                                : 'Pilih Semua (${filtered.length})',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: isAllSelected
                                  ? (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1))
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          backgroundColor: isAllSelected
                              ? (isDark
                                  ? const Color(0xFF0C4A6E).withValues(alpha: 0.6)
                                  : const Color(0xFFE0F2FE))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          side: BorderSide(
                            color: isAllSelected
                                ? const Color(0xFF38BDF8)
                                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            width: 1,
                          ),
                          onPressed: () => _toggleSelectAll(filtered),
                        );
                      },
                    ),
                    SizedBox(width: 6.w),
                    ActionChip(
                      avatar: const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF10B981)),
                      label: Text(
                        'Set Semua Naik',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _batchSetStatus('naik'),
                    ),
                    SizedBox(width: 6.w),
                    ActionChip(
                      avatar: const Icon(Icons.school_rounded, size: 16, color: Color(0xFF8B5CF6)),
                      label: Text(
                        'Set Semua Lulus',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _batchSetStatus('lulus'),
                    ),
                    SizedBox(width: 6.w),
                    ActionChip(
                      avatar: const Icon(Icons.replay_rounded, size: 16, color: Color(0xFFF59E0B)),
                      label: Text(
                        'Set Semua Tinggal',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _batchSetStatus('tidak_naik'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Counter bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpilih: ${_selectedStudentIds.length} dari ${_sourceStudents.length} siswa',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                'Total di filter: ${filtered.length}',
                style: GoogleFonts.hankenGrotesk(fontSize: 11.sp, color: Colors.grey),
              ),
            ],
          ),
        ),

        // List of students with status dropdown
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: AppEmptyWidget(
                    title: 'Tidak Ada Siswa',
                    subtitle: 'Tidak ada siswa yang cocok dengan pencarian.',
                    icon: Icons.people_outline,
                  ),
                )
              : Scrollbar(
                  controller: _studentsScrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _studentsScrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    itemCount: filtered.length,
                    separatorBuilder: (context, _) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      final isSelected = _selectedStudentIds.contains(student.id);
                      final status = _studentStatusMap[student.id] ?? (_isGraduationMode ? 'lulus' : 'naik');
                      final statusColor = _getStatusColor(status);

                      return Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                                  : const Color(0xFFEFF6FF))
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedStudentIds.add(student.id);
                                    _studentStatusMap.putIfAbsent(
                                      student.id,
                                      () => _isGraduationMode ? 'lulus' : 'naik',
                                    );
                                  } else {
                                    _selectedStudentIds.remove(student.id);
                                  }
                                });
                              },
                            ),
                            CircleAvatar(
                              radius: 16.r,
                              backgroundColor: statusColor.withValues(alpha: 0.15),
                              child: Text(
                                student.name.isNotEmpty
                                    ? student.name.substring(0, 1).toUpperCase()
                                    : 'S',
                                style: GoogleFonts.hankenGrotesk(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    student.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'NIS: ${student.nis ?? "-"} · ${student.gender == "L" ? "Laki-laki" : "Perempuan"}',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Status dropdown for this student
                            if (isSelected)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: status,
                                    isDense: true,
                                    icon: Icon(Icons.arrow_drop_down, color: statusColor),
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'naik', child: Text('Naik')),
                                      DropdownMenuItem(value: 'tidak_naik', child: Text('Tidak Naik')),
                                      DropdownMenuItem(value: 'lulus', child: Text('Lulus')),
                                      DropdownMenuItem(value: 'pindah', child: Text('Pindah')),
                                      DropdownMenuItem(value: 'tetap', child: Text('Tetap')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _studentStatusMap[student.id] = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStep3Verification(List<PeriodModel> periods, bool isDark) {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final classes = masterProvider.classes;

    final sourcePeriodName = periods.where((p) => p.id == _sourcePeriodId).firstOrNull?.name ?? '-';
    final sourceClassName = classes.where((c) => c.id == _sourceClassId).firstOrNull?.name ?? '-';

    final targetPeriodName = _isGraduationMode
        ? 'Tingkat Akhir'
        : (periods.where((p) => p.id == _targetPeriodId).firstOrNull?.name ?? '-');
    final targetClassName = _isGraduationMode
        ? 'Lulus (Selesai Pendidikan)'
        : (classes.where((c) => c.id == _targetClassId).firstOrNull?.name ?? '-');

    int naikCount = 0;
    int tidakNaikCount = 0;
    int lulusCount = 0;
    int pindahCount = 0;
    int tetapCount = 0;

    for (final id in _selectedStudentIds) {
      final st = _studentStatusMap[id] ?? (_isGraduationMode ? 'lulus' : 'naik');
      if (st == 'naik') naikCount++;
      if (st == 'tidak_naik') tidakNaikCount++;
      if (st == 'lulus') lulusCount++;
      if (st == 'pindah') pindahCount++;
      if (st == 'tetap') tetapCount++;
    }

    final selectedStudentsList = _sourceStudents.where((s) => _selectedStudentIds.contains(s.id)).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Verifikasi
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Pastikan data sudah benar sebelum konfirmasi.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Ringkasan Alur Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Perpindahan',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Asal & Tujuan
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox(
                          'DARI (ASAL)',
                          sourcePeriodName,
                          sourceClassName,
                          const Color(0xFF2563EB),
                          isDark,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                      ),
                      Expanded(
                        child: _buildSummaryBox(
                          'KE (TUJUAN)',
                          targetPeriodName,
                          targetClassName,
                          _isGraduationMode ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Statistik Breakdown Status
                  Text(
                    'Rincian Status Siswa Yang Akan Diproses (${_selectedStudentIds.length} Siswa):',
                    style: GoogleFonts.hankenGrotesk(fontSize: 12.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      if (naikCount > 0)
                        _buildStatusPill('Naik Kelas', naikCount, const Color(0xFF10B981)),
                      if (tidakNaikCount > 0)
                        _buildStatusPill('Tinggal Kelas', tidakNaikCount, const Color(0xFFF59E0B)),
                      if (lulusCount > 0)
                        _buildStatusPill('Lulus', lulusCount, const Color(0xFF8B5CF6)),
                      if (pindahCount > 0)
                        _buildStatusPill('Pindah', pindahCount, const Color(0xFF06B6D4)),
                      if (tetapCount > 0)
                        _buildStatusPill('Tetap', tetapCount, const Color(0xFF64748B)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Daftar Siswa Terverifikasi
          Text(
            'Daftar Siswa Yang Diproses:',
            style: GoogleFonts.hankenGrotesk(fontSize: 13.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedStudentsList.length,
            separatorBuilder: (context, _) => SizedBox(height: 6.h),
            itemBuilder: (context, index) {
              final student = selectedStudentsList[index];
              final status = _studentStatusMap[student.id] ?? (_isGraduationMode ? 'lulus' : 'naik');
              final statusColor = _getStatusColor(status);

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'NIS: ${student.nis ?? "-"}',
                            style: GoogleFonts.hankenGrotesk(fontSize: 11.sp, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _formatStatusLabel(status),
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String label, String period, String className, Color accentColor, bool isDark) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            period,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.sp,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            className,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            '$label: $count',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Kembali'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: EdgeInsets.symmetric(horizontal: 14.w),
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep == 0) {
                        if (_validateStep1()) setState(() => _currentStep = 1);
                      } else if (_currentStep == 1) {
                        if (_validateStep2()) setState(() => _currentStep = 2);
                      } else {
                        _handleProcessPromotions();
                      }
                    },
              icon: Icon(
                _currentStep == 2 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                _currentStep == 2
                    ? 'Konfirmasi'
                    : (_currentStep == 0 ? 'Pilih Siswa' : 'Verifikasi'),
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold, fontSize: 13.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
