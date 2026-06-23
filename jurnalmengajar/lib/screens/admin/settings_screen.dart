import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
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
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.loadSettings();
    if (settingsProvider.settings != null) {
      _daysController.text = '${settingsProvider.settings!.maxJournalInputDays}';
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
        AppHelper.showSnackBar(context, 'Batas hari harus berupa angka positif', isError: true);
        return;
      }

      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final currentSettings = settingsProvider.settings;
      if (currentSettings != null) {
        final newSettings = currentSettings.copyWith(maxJournalInputDays: days);
        final success = await settingsProvider.saveSettings(newSettings);

        if (success && mounted) {
          AppHelper.showSnackBar(context, 'Pengaturan sistem berhasil disimpan!');
        } else if (mounted) {
          AppHelper.showSnackBar(context, settingsProvider.errorMessage ?? 'Gagal menyimpan pengaturan.', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isLoading = settingsProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Sistem'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/settings'),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.all(20.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
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
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
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
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      
                      ElevatedButton.icon(
                        onPressed: isLoading ? null : _handleSave,
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan Pengaturan'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
