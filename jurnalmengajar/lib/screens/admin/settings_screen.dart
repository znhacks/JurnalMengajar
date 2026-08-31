import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ganti Kode Aktivasi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Masukkan kode aktivasi langganan dari JM-Panel:'),
                SizedBox(height: 12.h),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Aktivasi',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        if (code.isEmpty) return;

                        setState(() => isChecking = true);
                        final masterProvider = Provider.of<MasterDataProvider>(
                          this.context,
                          listen: false,
                        );
                        final validPlan = await masterProvider
                            .validateActivationCode(code);
                        setState(() => isChecking = false);

                        if (validPlan != null) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          _showConfirmationDialog(validPlan, code);
                        } else {
                          if (!mounted) return;
                          AppHelper.showSnackBar(
                            this.context,
                            'Kode aktivasi tidak valid atau tidak ditemukan.',
                            isError: true,
                          );
                        }
                      },
                child: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cek Kode'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmationDialog(String plan, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Aktivasi'),
        content: Text(
          'Anda akan mengaktifkan paket $plan.\n\nLanjut / Edit?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showActivationCodeDialog();
            },
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final masterProvider = Provider.of<MasterDataProvider>(
                this.context,
                listen: false,
              );
              final school = masterProvider.schools.isNotEmpty
                  ? masterProvider.schools.first
                  : null;
              if (school != null) {
                final success = await masterProvider.updateSchoolPlan(
                  school.id,
                  plan,
                  code,
                );
                if (success && mounted) {
                  AppHelper.showSnackBar(
                    this.context,
                    'Berhasil mengaktifkan paket $plan.',
                  );
                } else if (mounted) {
                  AppHelper.showSnackBar(
                    this.context,
                    'Gagal mengaktifkan paket.',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchJMPanel() async {
    final url = Uri.parse('https://jmpanel.vercel.app');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Tidak dapat membuka tautan.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final isLoading = settingsProvider.isLoading || masterProvider.isLoading;
    final school = masterProvider.schools.isNotEmpty ? masterProvider.schools.first : null;
    final plan = school?.plan ?? 'free';
    final isPro = plan == 'pro';

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Sistem')),
      drawer: const AdminDrawer(currentRoute: '/admin/settings'),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Paket Berlangganan Section
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: isPro ? Colors.blue.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Paket Berlangganan',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: isPro ? Colors.blue : Colors.grey[600],
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    isPro ? 'PRO PLAN' : 'FREE PLAN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              isPro
                                  ? 'Anda sedang menggunakan Paket PRO. (Maksimal 50 Guru)'
                                  : 'Anda sedang menggunakan Paket FREE. (Maksimal 30 Guru)',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showActivationCodeDialog,
                                    icon: const Icon(Icons.key),
                                    label: const Text('Ganti Kode Aktivasi'),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _launchJMPanel,
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Kelola Langganan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F7CFF),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Pengaturan Input Jurnal Section
                    Form(
                      key: _formKey,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Batasan Penginputan Jurnal',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Tentukan batas waktu (dalam hari) bagi guru untuk mengisi jurnal setelah jadwal mengajar selesai.',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                              const Divider(height: 28),

                              Text(
                                'Batas Waktu Input (Hari) *',
                                style: TextStyle(
                                  fontSize: 14.sp,
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
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: 3',
                                  suffixText: 'Hari',
                                  fillColor: Colors.white,
                                ),
                              ),
                              SizedBox(height: 24.h),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isLoading ? null : _handleSave,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Simpan Pengaturan Jurnal'),
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
