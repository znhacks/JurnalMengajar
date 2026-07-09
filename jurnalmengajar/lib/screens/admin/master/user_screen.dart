import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterUserScreen extends StatefulWidget {
  const MasterUserScreen({super.key});

  @override
  State<MasterUserScreen> createState() => _MasterUserScreenState();
}

class _MasterUserScreenState extends State<MasterUserScreen> {
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsers();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final users = await authProvider.getAllUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.fullName.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _handleRoleToggle(UserModel user, bool makeAdmin) async {
    final newRole = makeAdmin ? 'admin' : 'guru';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Safety check: Cannot demote the main admin account or current logged-in user
    if (!makeAdmin && user.email.toLowerCase() == 'admin@jurnal.com') {
      AppHelper.showSnackBar(
        context, 
        'Akun admin utama (admin@jurnal.com) tidak bisa diturunkan menjadi guru.', 
        isError: true
      );
      return;
    }

    if (!makeAdmin && user.id == authProvider.currentUser?.id) {
      AppHelper.showSnackBar(
        context, 
        'Anda tidak dapat menurunkan peran Anda sendiri untuk mencegah penguncian akun.', 
        isError: true
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(makeAdmin ? 'Jadikan Administrator' : 'Ubah Menjadi Guru'),
        content: Text(
          makeAdmin 
            ? 'Apakah Anda yakin ingin mempromosikan ${user.fullName} menjadi Administrator? Akun ini akan memiliki akses penuh ke panel admin.' 
            : 'Apakah Anda yakin ingin mengubah peran ${user.fullName} menjadi Guru? Akses administratif akan dicabut.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Batal')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              makeAdmin ? 'Promosikan' : 'Turunkan', 
              style: TextStyle(color: makeAdmin ? Colors.indigo : Colors.red)
            )
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      final success = await authProvider.updateUserRole(user.id, newRole);

      if (!mounted) return;

      if (success) {
        AppHelper.showSnackBar(context, 'Peran ${user.fullName} berhasil diperbarui menjadi ${newRole.toUpperCase()}!');
        _fetchUsers();
      } else {
        AppHelper.showSnackBar(
          context, 
          authProvider.errorMessage ?? 'Gagal memperbarui peran.', 
          isError: true
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDeleteUser(UserModel user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Safety checks
    if (user.email.toLowerCase() == 'admin@jurnal.com') {
      AppHelper.showSnackBar(
        context, 
        'Akun admin utama tidak boleh dihapus.', 
        isError: true
      );
      return;
    }

    if (user.id == authProvider.currentUser?.id) {
      AppHelper.showSnackBar(
        context, 
        'Untuk menghapus akun Anda sendiri, gunakan menu "Hapus Akun" di Profil Saya.', 
        isError: true
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun Pengguna', style: TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus akun ${user.fullName}? Tindakan ini bersifat permanen dan tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Akun', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      final success = await authProvider.deleteAccount(user.id);
      
      if (!mounted) return;

      if (success) {
        AppHelper.showSnackBar(context, 'Akun ${user.fullName} berhasil dihapus!');
        _fetchUsers();
      } else {
        AppHelper.showSnackBar(
          context, 
          authProvider.errorMessage ?? 'Gagal menghapus akun.', 
          isError: true
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApproveUser(UserModel user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Pendaftaran Guru'),
        content: Text('Apakah Anda yakin ingin menyetujui pendaftaran ${user.fullName} sebagai Guru?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Batal')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setujui', style: TextStyle(color: Colors.green))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      final success = await authProvider.updateUserRole(user.id, 'guru');

      if (!mounted) return;

      if (success) {
        AppHelper.showSnackBar(context, 'Akun ${user.fullName} berhasil disetujui sebagai GURU!');
        _fetchUsers();
      } else {
        AppHelper.showSnackBar(
          context, 
          authProvider.errorMessage ?? 'Gagal menyetujui pendaftaran.', 
          isError: true
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRejectUser(UserModel user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pendaftaran', style: TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menolak pendaftaran ${user.fullName}? Akun pendaftaran ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tolak & Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      final success = await authProvider.deleteAccount(user.id);
      
      if (!mounted) return;

      if (success) {
        AppHelper.showSnackBar(context, 'Pendaftaran ${user.fullName} berhasil ditolak.');
        _fetchUsers();
      } else {
        AppHelper.showSnackBar(
          context, 
          authProvider.errorMessage ?? 'Gagal menolak pendaftaran.', 
          isError: true
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildUserList(List<UserModel> users, AuthProvider authProvider, {required bool isPendingTab}) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: users.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final user = users[index];
        final isAdmin = user.role == 'admin';
        final isSuperAdmin = user.email.toLowerCase() == 'admin@jurnal.com';
        final isCurrentUser = user.id == authProvider.currentUser?.id;

        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26.r,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: user.photoUrl != null && user.photoUrl!.startsWith('http')
                    ? NetworkImage(user.photoUrl!)
                    : (user.photoUrl != null
                        ? FileImage(File(user.photoUrl!))
                        : null) as ImageProvider?,
                child: user.photoUrl == null
                    ? Icon(Icons.person_outline, size: 26.r, color: Colors.grey[400])
                    : null,
              ),
              SizedBox(width: 14.w),
              
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        // Role badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: isPendingTab
                                ? const Color(0xFFFFFBEB)
                                : (isAdmin 
                                    ? const Color(0xFFEEF2FF) 
                                    : const Color(0xFFF0FDFA)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPendingTab
                                  ? const Color(0xFFFDE68A)
                                  : (isAdmin 
                                      ? const Color(0xFFC7D2FE) 
                                      : const Color(0xFFCCFBF1))
                            ),
                          ),
                          child: Text(
                            isPendingTab ? 'PENDING' : user.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: isPendingTab
                                  ? const Color(0xFFD97706)
                                  : (isAdmin 
                                      ? const Color(0xFF4F46E5) 
                                      : const Color(0xFF2563EB))
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Telp: ${user.phoneNumber}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                    if (isCurrentUser) ...[
                      SizedBox(height: 4.h),
                      Text(
                        '(Akun Anda)',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey[450],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              
              // Action panel
              if (isPendingTab) ...[
                // Approval Action Buttons (Terima, Tolak)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Setujui Pendaftaran',
                      onPressed: () => _handleApproveUser(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      tooltip: 'Tolak Pendaftaran',
                      onPressed: () => _handleRejectUser(user),
                    ),
                  ],
                ),
              ] else ...[
                // Switch to make admin, Delete button for Active Users
                Column(
                  children: [
                    Switch(
                      value: isAdmin,
                      activeThumbColor: const Color(0xFF4F46E5),
                      onChanged: (isSuperAdmin || isCurrentUser)
                          ? null
                          : (val) => _handleRoleToggle(user, val),
                    ),
                    Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: (isSuperAdmin || isCurrentUser) 
                            ? Colors.grey[400] 
                            : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!isSuperAdmin && !isCurrentUser) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _handleDeleteUser(user),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final activeUsers = _filteredUsers.where((u) => u.role == 'guru' || u.role == 'admin').toList();
    final pendingUsers = _filteredUsers.where((u) => u.role == 'pending_guru').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master User & Hak Akses'),
          bottom: TabBar(
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF2563EB),
            tabs: [
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline),
                    SizedBox(width: 8),
                    Text('Pengguna Aktif'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add_outlined),
                    const SizedBox(width: 8),
                    const Text('Guru Mendaftar'),
                    if (pendingUsers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${pendingUsers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        drawer: const AdminDrawer(currentRoute: '/admin/master-data/users'),
        body: RefreshIndicator(
          onRefresh: _fetchUsers,
          color: const Color(0xFF2563EB),
          child: Column(
            children: [
              // Search field
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading && _allUsers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? AppErrorWidget(
                            message: _errorMessage!,
                            onRetry: _fetchUsers,
                          )
                        : TabBarView(
                            children: [
                              activeUsers.isEmpty
                                  ? const AppEmptyWidget(
                                      title: 'Pengguna Tidak Ditemukan',
                                      subtitle: 'Tidak ada pengguna aktif terdaftar.',
                                    )
                                  : _buildUserList(activeUsers, authProvider, isPendingTab: false),
                              pendingUsers.isEmpty
                                  ? const AppEmptyWidget(
                                      title: 'Tidak Ada Pendaftaran',
                                      subtitle: 'Tidak ada guru baru yang sedang mendaftar.',
                                    )
                                  : _buildUserList(pendingUsers, authProvider, isPendingTab: true),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
