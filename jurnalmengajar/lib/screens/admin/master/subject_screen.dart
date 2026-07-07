import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterSubjectScreen extends StatefulWidget {
  const MasterSubjectScreen({super.key});

  @override
  State<MasterSubjectScreen> createState() => _MasterSubjectScreenState();
}

class _MasterSubjectScreenState extends State<MasterSubjectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({SubjectModel? subject}) {
    final nameController = TextEditingController(text: subject?.name ?? '');
    bool isActive = subject?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    subject == null ? 'Tambah Mata Pelajaran Baru' : 'Edit Mata Pelajaran',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Mata Pelajaran',
                      hintText: 'Contoh: Matematika Peminatan',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SwitchListTile(
                    title: const Text('Status Aktif'),
                    subtitle: const Text('Apakah mata pelajaran ini aktif digunakan saat ini'),
                    value: isActive,
                    activeThumbColor: const Color(0xFF0D9488),
                    onChanged: (val) {
                      setDialogState(() {
                        isActive = val;
                      });
                    },
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        AppHelper.showSnackBar(context, 'Nama pelajaran tidak boleh kosong', isError: true);
                        return;
                      }

                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                      bool success;

                      if (subject == null) {
                        success = await masterProvider.createSubject(SubjectModel(
                          id: '',
                          name: nameController.text.trim(),
                          isActive: isActive,
                        ));
                      } else {
                        success = await masterProvider.updateSubject(subject.copyWith(
                          name: nameController.text.trim(),
                          isActive: isActive,
                        ));
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(context, 'Mata pelajaran berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan mata pelajaran.', isError: true);
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final success = await masterProvider.deleteSubject(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Mata pelajaran berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus mata pelajaran.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final subjects = masterProvider.subjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Pelajaran'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/subjects'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : subjects.isEmpty
                ? const AppEmptyWidget(
                    title: 'Mata Pelajaran Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah daftar pelajaran.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: subjects.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return Dismissible(
                        key: Key(subject.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20.w),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _handleDelete(subject.id),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Pelajaran'),
                              content: const Text('Apakah Anda yakin ingin menghapus mata pelajaran ini?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: subject.isActive ? const Color(0xFF0D9488).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                child: Icon(
                                  subject.isActive ? Icons.menu_book : Icons.block,
                                  color: subject.isActive ? const Color(0xFF0D9488) : Colors.red,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject.name,
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      subject.isActive ? 'Aktif' : 'Tidak Aktif',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: subject.isActive ? const Color(0xFF0D9488) : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                                    onPressed: () => _showFormDialog(subject: subject),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Hapus Pelajaran'),
                                          content: const Text('Apakah Anda yakin ingin menghapus mata pelajaran ini?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        _handleDelete(subject.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
