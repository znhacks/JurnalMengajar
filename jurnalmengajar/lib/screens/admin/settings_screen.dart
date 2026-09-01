import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/school_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _daysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await settingsProvider.loadSettings();
    if (settingsProvider.settings != null) {
      _daysController.text =
          '${settingsProvider.settings!.maxJournalInputDays}';
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final days = int.tryParse(_daysController.text.trim());
      if (days == null || days < 0) {
        AppHelper.showSnackBar(
          context,
          'Batas hari harus berupa angka positif',
          isError: true,
        );
        return;
      }

      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final currentSettings = settingsProvider.settings;
      if (currentSettings != null) {
        final newSettings = currentSettings.copyWith(maxJournalInputDays: days);
        final success = await settingsProvider.saveSettings(newSettings);

        if (success && mounted) {
          AppHelper.showSnackBar(
            context,
            'Pengaturan sistem berhasil disimpan!',
          );
        } else if (mounted) {
          AppHelper.showSnackBar(
            context,
            settingsProvider.errorMessage ?? 'Gagal menyimpan pengaturan.',
            isError: true,
          );
        }
      }
    }
  }

  void _showActivationCodeDialog() {
    final codeController = TextEditingController();
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Ganti Kode Aktivasi',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Masukkan kode sekolah / lisensi yang diperoleh dari JM-Panel (misal: PRO-XXXXXX atau KODE-SEKOLAH):',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Kode Aktivasi / Sekolah',
                    hintText: 'Contoh: PRO-684D386E',
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        if (code.isEmpty) {
                          AppHelper.showSnackBar(
                            context,
                            'Silakan masukkan kode terlebih dahulu.',
                            isError: true,
                          );
                          return;
                        }

                        setModalState(() => isChecking = true);
                        final masterProvider = Provider.of<MasterDataProvider>(
                          context,
                          listen: false,
                        );
                        
                        final matchedSchool = await masterProvider.validateActivationCode(code);
                        if (!dialogContext.mounted || !mounted) return;
                        setModalState(() => isChecking = false);

                        if (matchedSchool != null) {
                          Navigator.pop(dialogContext);
                          _showConfirmationDialog(matchedSchool, code);
                        } else {
                          AppHelper.showSnackBar(
                            context,
                            'Kode tidak valid atau tidak ditemukan di database JM-Panel.',
                            isError: true,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: isChecking
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Cek Kode'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmationDialog(SchoolModel matchedSchool, String code) {
    final isPro = matchedSchool.isPro;
    final planName = matchedSchool.plan.toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
        ),
        title: Row(
          children: [
            Icon(
              isPro ? Icons.stars_rounded : Icons.verified_rounded,
              color: isPro ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              size: 28,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Konfirmasi Paket $planName',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan mengaktifkan dan menerapkan paket berikut untuk sekolah Anda:',
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: isPro
                    ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFFFBEB))
                    : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isPro
                      ? (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A))
                      : (isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          matchedSchool.name,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: isPro ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '$planName PLAN',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Kode: ${matchedSchool.code ?? code}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isPro
                          ? (isDark ? const Color(0xFFFED7AA) : const Color(0xFF92400E))
                          : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Divider(
                    height: 16,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 16.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 6.w),
                      Text(
                        'Kapasitas Maksimal: ${matchedSchool.maxTeachers} Guru',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16.sp, color: Colors.green[600]),
                      SizedBox(width: 6.w),
                      Text(
                        isPro ? 'Perks: Prioritas & Multi-Sekolah' : 'Perks: Fitur Standar Sekolah',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(confirmCtx);
              _showActivationCodeDialog();
            },
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(confirmCtx);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
              final userId = authProvider.currentUser?.id;

              try {
                // 1. Connect user to school with role 'admin' in user_schools if not yet connected
                if (userId != null) {
                  final supabase = Supabase.instance.client;
                  final existing = await supabase
                      .from('user_schools')
                      .select('id')
                      .eq('user_id', userId)
                      .eq('school_id', matchedSchool.id)
                      .maybeSingle();

                  if (existing == null) {
                    await supabase.from('user_schools').insert({
                      'user_id': userId,
                      'school_id': matchedSchool.id,
                      'role': 'admin',
                    });
                  }
                }

                // 2. Update active school & refresh
                await authProvider.switchActiveSchool(
                  matchedSchool.id,
                  matchedSchool.name,
                  'admin',
                );
                await authProvider.loadUserMemberships();
                await masterProvider.loadAllData(matchedSchool.id);

                if (mounted) {
                  setState(() {});
                  AppHelper.showSnackBar(
                    context,
                    'Selamat! Paket $planName untuk ${matchedSchool.name} berhasil diaktifkan.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  AppHelper.showSnackBar(
                    context,
                    'Gagal mengaktifkan paket: $e',
                    isError: true,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isPro ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: const Text('Lanjut & Terapkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchJMPanel() async {
    final url = Uri.parse('https://jmpanel.vercel.app');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppHelper.showSnackBar(context, 'Tidak dapat membuka tautan jmpanel.vercel.app', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Gagal membuka browser: $e', isError: true);
      }
    }
  }

  Widget _buildPerkItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? const Color(0xFFD97706).withValues(alpha: 0.12)
                  : const Color(0xFF2563EB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16.sp,
              color: isHighlighted ? const Color(0xFFD97706) : const Color(0xFF2563EB),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final isLoading = settingsProvider.isLoading || masterProvider.isLoading;

    SchoolModel? school = authProvider.activeSchool;
    if (school == null && authProvider.activeSchoolId != null) {
      try {
        school = masterProvider.schools.firstWhere((s) => s.id == authProvider.activeSchoolId);
      } catch (_) {}
    }
    school ??= masterProvider.schools.isNotEmpty ? masterProvider.schools.first : null;

    final plan = (school?.plan ?? 'free').toLowerCase().trim();
    final isPro = plan == 'pro';
    final isEnterprise = plan == 'enterprise';
    final maxTeachers = school?.maxTeachers ?? (isPro ? 50 : 30);
    final currentTeacherCount = masterProvider.teachers.length;
    final usagePercent = maxTeachers > 0 ? (currentTeacherCount / maxTeachers).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan Sekolah',
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/settings'),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(18.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── 1. KARTU PAKET BERLANGGANAN & PERKS ────────────────────────
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                        side: BorderSide(
                          color: isPro
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                              : Colors.grey.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(18.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Plan Badge & School Info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        gradient: isPro
                                            ? const LinearGradient(
                                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : const LinearGradient(
                                                colors: [Color(0xFF64748B), Color(0xFF475569)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                        borderRadius: BorderRadius.circular(14.r),
                                      ),
                                      child: Icon(
                                        isPro ? Icons.workspace_premium_rounded : Icons.school_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Paket Aplikasi',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          isPro
                                              ? 'PRO PLAN'
                                              : (isEnterprise ? 'ENTERPRISE' : 'FREE PLAN'),
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.w900,
                                            color: isPro
                                                ? const Color(0xFFD97706)
                                                : Theme.of(context).colorScheme.onSurface,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                  decoration: BoxDecoration(
                                    color: isPro
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B),
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPro ? Icons.star_rounded : Icons.check_rounded,
                                        size: 14.sp,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        isPro ? 'AKTIF' : 'GRATIS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),

                            // School name and Code Row
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          school?.name ?? 'Sekolah',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Kode Sekolah: ${school?.code ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (school?.code != null)
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      tooltip: 'Salin Kode',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: school!.code!));
                                        AppHelper.showSnackBar(context, 'Kode sekolah disalin!');
                                      },
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Teacher Quota Progress Indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kapasitas Guru Terdaftar',
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '$currentTeacherCount / $maxTeachers Guru',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: currentTeacherCount >= maxTeachers
                                        ? Colors.red
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6.r),
                              child: LinearProgressIndicator(
                                value: usagePercent,
                                minHeight: 8.h,
                                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  currentTeacherCount >= maxTeachers
                                      ? Colors.red
                                      : (isPro ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
                                ),
                              ),
                            ),
                            SizedBox(height: 18.h),

                            // Perks Breakdown
                            Text(
                              'Keuntungan & Fitur Paket:',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 8.h),

                            _buildPerkItem(
                              icon: Icons.groups_rounded,
                              title: isPro ? 'Maksimal 50 Guru' : 'Maksimal 30 Guru',
                              subtitle: isPro
                                  ? 'Kapasitas Pro hingga 50 guru di aplikasi Jurnal Mengajar'
                                  : 'Kapasitas Free plan maksimal 30 guru (Upgrade ke Pro untuk 50 guru)',
                              isHighlighted: isPro,
                            ),
                            _buildPerkItem(
                              icon: Icons.domain_rounded,
                              title: isPro ? 'Kontrol 2 Sekolah di JM-Panel' : 'Kontrol 1 Sekolah',
                              subtitle: isPro
                                  ? 'Dapat mengelola hingga 2 instansi/sekolah sekaligus'
                                  : 'Hanya dapat mengelola 1 instansi sekolah',
                              isHighlighted: isPro,
                            ),
                            _buildPerkItem(
                              icon: Icons.support_agent_rounded,
                              title: isPro ? 'Dukungan Prioritas (Priority Support)' : 'Dukungan Komunitas',
                              subtitle: isPro
                                  ? 'Respon cepat dan penanganan langsung untuk admin Pro'
                                  : 'Dukungan standar aplikasi',
                              isHighlighted: isPro,
                            ),
                            _buildPerkItem(
                              icon: Icons.manage_accounts_rounded,
                              title: isPro ? '2 Pengguna di Organisasi' : '1 Pengguna di Organisasi',
                              subtitle: isPro
                                  ? 'Akses multi-admin untuk pengelolaan sekolah'
                                  : '1 akun pengelola organisasi',
                              isHighlighted: isPro,
                            ),

                            SizedBox(height: 18.h),

                            // Action Buttons: Ganti Kode & Kelola Langganan
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showActivationCodeDialog,
                                    icon: const Icon(Icons.vpn_key_rounded, size: 18),
                                    label: Text(
                                      'Ganti Kode',
                                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: 12.h),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _launchJMPanel,
                                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                    label: Text(
                                      'Kelola Langganan',
                                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 12.h),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // ─── 2. PENGATURAN INPUT JURNAL SECTION ─────────────────────────
                    Form(
                      key: _formKey,
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(18.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: const Icon(
                                      Icons.timer_outlined,
                                      color: Color(0xFF2563EB),
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Batasan Penginputan Jurnal',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 15.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                'Tentukan batas waktu (dalam hari) bagi guru untuk mengisi jurnal setelah jadwal mengajar selesai.',
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const Divider(height: 24),

                              Text(
                                'Batas Waktu Input (Hari) *',
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              TextFormField(
                                controller: _daysController,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Batas hari tidak boleh kosong';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 3',
                                  suffixText: 'Hari',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                              ),
                              SizedBox(height: 18.h),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isLoading ? null : _handleSave,
                                  icon: const Icon(Icons.save_rounded),
                                  label: Text(
                                    'Simpan Pengaturan Jurnal',
                                    style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
